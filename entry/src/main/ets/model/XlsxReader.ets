/**
 * XLSX 读取（不依赖三方库）
 *
 * 流程：把 picker 选中的文件复制到沙箱 -> zlib 解压 zip -> 解析 workbook/rels/sharedStrings
 * -> 逐表解析 <row>/<c>，再按表名映射成 记录 / 航次 / 油耗率。
 */
import { common } from '@kit.AbilityKit';
import { zlib } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { NO_TIME, ShipRecord, ShipStatus } from './Types';
import { floorToMinute, localOffsetMin, wallToMs } from './Calc';

export class ImportedSheet {
  name: string = '';
  /** 行 -> 列（稀疏用 Map，col 为 0 基） */
  rows: Map<number, string>[] = [];
}

export class ExcelImportResult {
  records: ShipRecord[] = [];
  voyageName: string = '';
  voyageTimes: number[] = [NO_TIME, NO_TIME, NO_TIME]; // 上次抵港/上次离港/本次抵港
  oils: number[] = [-1, -1, -1, -1, -1];               // 上次抵港/上次离港/本次抵港/添加/驳出
  rates: Map<string, number> = new Map<string, number>();
  errors: string[] = [];
  sheetNames: string[] = [];
}

// ---------------- XML 小工具 ----------------

function unescapeXml(s: string): string {
  return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/&apos;/g, '\'').replace(/&#(\d+);/g, (m: string, d: string) => String.fromCharCode(parseInt(d)))
    .replace(/&amp;/g, '&');
}

function attr(attrs: string, name: string): string {
  const m = attrs.match(new RegExp(name + '\\s*=\\s*"([^"]*)"'));
  return m === null ? '' : m[1];
}

function colIndex(ref: string): number {
  const m = ref.match(/^([A-Z]+)/);
  if (m === null) {
    return -1;
  }
  let n: number = 0;
  const letters: string = m[1];
  for (let i: number = 0; i < letters.length; i++) {
    n = n * 26 + (letters.charCodeAt(i) - 64);
  }
  return n - 1;
}

function readText(path: string): string {
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
  try {
    const stat = fs.statSync(file.fd);
    if (stat.size <= 0) {
      return '';
    }
    const buf = new ArrayBuffer(stat.size);
    const len: number = fs.readSync(file.fd, buf);
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf.slice(0, len)));
  } finally {
    fs.closeSync(file);
  }
}

/** 解析 sharedStrings.xml -> 字符串数组 */
function parseSharedStrings(xmlText: string): string[] {
  const out: string[] = [];
  const re = /<si>([\s\S]*?)<\/si>/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(xmlText)) !== null) {
    const inner: string = m[1];
    const t = inner.match(/<t[^>]*>([\s\S]*?)<\/t>/);
    out.push(t === null ? '' : unescapeXml(t[1]));
  }
  return out;
}

/** 解析一张工作表 */
function parseSheet(xmlText: string, shared: string[]): Map<number, string>[] {
  const rows: Map<number, string>[] = [];
  const rowRe = /<row[^>]*>([\s\S]*?)<\/row>/g;
  let rm: RegExpExecArray | null;
  while ((rm = rowRe.exec(xmlText)) !== null) {
    const rowXml: string = rm[1];
    const cells = new Map<number, string>();
    const cellRe = /<c([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g;
    let cm: RegExpExecArray | null;
    while ((cm = cellRe.exec(rowXml)) !== null) {
      const attrs: string = cm[1] ?? '';
      const body: string = cm[2] ?? '';
      const ref: string = attr(attrs, 'r');
      const type: string = attr(attrs, 't');
      const idx: number = colIndex(ref);
      if (idx < 0) {
        continue;
      }
      let value: string = '';
      if (type === 'inlineStr') {
        const t = body.match(/<t[^>]*>([\s\S]*?)<\/t>/);
        value = t === null ? '' : unescapeXml(t[1]);
      } else {
        const v = body.match(/<v>([\s\S]*?)<\/v>/);
        if (v !== null) {
          const raw: string = unescapeXml(v[1]);
          value = type === 's' ? (shared[parseInt(raw)] ?? '') : raw;
        }
      }
      cells.set(idx, value);
    }
    rows.push(cells);
  }
  return rows;
}

// ---------------- 数值 / 时间 ----------------

function parseWall(text: string): number {
  const t: string = text.trim().replace(/\//g, '-');
  const m = t.match(/^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?/);
  if (m === null) {
    return NaN;
  }
  return wallToMs(parseInt(m[1]), parseInt(m[2]), parseInt(m[3]),
    parseInt(m[4]), parseInt(m[5]), m[6] ? parseInt(m[6]) : 0);
}

/** 时间单元格：文本日期 或 Excel 序列号 */
function cellToWall(text: string): number {
  const t: string = text.trim();
  if (t.length === 0) {
    return NaN;
  }
  const n: number = Number(t);
  if (!isNaN(n) && n > 20000 && n < 80000) {
    // Excel 序列号（1899-12-30 起算），按 UTC 解释为朴素墙钟
    return floorToMinute(Math.round((n - 25569) * 86400000 / 60000) * 60000);
  }
  const wall: number = parseWall(t);
  return isNaN(wall) ? NaN : floorToMinute(wall);
}

function statusOf(text: string): ShipStatus | null {
  const t: string = text.trim();
  switch (t) {
    case '航行': case 'sailing': return ShipStatus.Sailing;
    case '锚泊': case 'anchorage': return ShipStatus.Anchorage;
    // 漂航 / 飘航 为同一状态的不同写法，都接受
    case '漂航': case '飘航': case 'drifting': return ShipStatus.Drifting;
    case '靠泊': case 'berthing': return ShipStatus.Berthing;
    case '系浮筒': case 'buoy': return ShipStatus.Buoy;
    default: return null;
  }
}

function numOrNeg(text: string): number {
  const t: string = text.trim();
  if (t.length === 0) {
    return -1;
  }
  const n: number = Number(t);
  return isNaN(n) ? -1 : n;
}

function newId(): string {
  return Date.now().toString(36) + Math.floor(Math.random() * 100000).toString(36);
}

// ---------------- 主流程 ----------------

function rmDir(path: string): void {
  try {
    if (fs.accessSync(path)) {
      fs.rmdirSync(path);
    }
  } catch (e) {
    // ignore
  }
}

/** 解压 xlsx 到沙箱并解析成表 */
export async function readXlsx(ctx: common.UIAbilityContext, uri: string): Promise<ImportedSheet[]> {
  const dir: string = ctx.cacheDir + '/xlsx_import';
  const zipPath: string = ctx.cacheDir + '/xlsx_import.zip';
  // decompressFile 要求目标目录必须已存在
  rmDir(dir);
  if (!fs.accessSync(dir)) {
    fs.mkdirSync(dir);
  }

  // 1) 复制到沙箱
  const src = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  try {
    const stat = fs.statSync(src.fd);
    const buf = new ArrayBuffer(stat.size);
    const len: number = fs.readSync(src.fd, buf);
    const dst = fs.openSync(zipPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(dst.fd, buf.slice(0, len));
    } finally {
      fs.closeSync(dst);
    }
  } finally {
    fs.closeSync(src);
  }

  // 2) 解压
  await zlib.decompressFile(zipPath, dir);

  // 3) 共享字符串
  let shared: string[] = [];
  const ssPath: string = dir + '/xl/sharedStrings.xml';
  if (fs.accessSync(ssPath)) {
    shared = parseSharedStrings(readText(ssPath));
  }

  // 4) workbook -> sheet 名与 rId
  const wb: string = readText(dir + '/xl/workbook.xml');
  const names: string[] = [];
  const rids: string[] = [];
  const sheetRe = /<sheet\b([^>]*)\/>/g;
  let m: RegExpExecArray | null;
  while ((m = sheetRe.exec(wb)) !== null) {
    names.push(unescapeXml(attr(m[1], 'name')));
    rids.push(attr(m[1], 'r:id'));
  }

  // 5) rels -> rId 对应文件
  const rels: string = readText(dir + '/xl/_rels/workbook.xml.rels');
  const targets: Map<string, string> = new Map<string, string>();
  const relRe = /<Relationship\b([^>]*)\/>/g;
  while ((m = relRe.exec(rels)) !== null) {
    const id: string = attr(m[1], 'Id');
    const target: string = attr(m[1], 'Target');
    if (id.length > 0 && target.length > 0) {
      targets.set(id, target.startsWith('/') ? target.substring(1) : 'xl/' + target);
    }
  }

  const out: ImportedSheet[] = [];
  for (let i: number = 0; i < names.length; i++) {
    const path: string | undefined = targets.get(rids[i]);
    const sheet = new ImportedSheet();
    sheet.name = names[i];
    if (path !== undefined) {
      const full: string = dir + '/' + path;
      if (fs.accessSync(full)) {
        sheet.rows = parseSheet(readText(full), shared);
      }
    }
    out.push(sheet);
  }

  // 清理
  try {
    fs.unlinkSync(zipPath);
  } catch (e) {
    // ignore
  }
  return out;
}

/** 把各表内容映射为业务数据 */
export function mapSheets(sheets: ImportedSheet[]): ExcelImportResult {
  const res = new ExcelImportResult();
  for (let i: number = 0; i < sheets.length; i++) {
    res.sheetNames.push(sheets[i].name);
    const sheet = sheets[i];

    if (sheet.name.indexOf('时间区间') >= 0) {
      mapDetail(sheet, res);
    } else if (sheet.name.indexOf('航次') >= 0) {
      mapVoyage(sheet, res);
    } else if (sheet.name.indexOf('油耗参数') >= 0) {
      mapRates(sheet, res);
    }
  }
  if (res.records.length === 0 && res.errors.length === 0) {
    res.errors.push('未找到「时间区间明细」工作表，或该表没有数据行');
  }
  return res;
}

function mapDetail(sheet: ImportedSheet, res: ExcelImportResult): void {
  let iStart: number = 1;
  let iEnd: number = 2;
  let iStatus: number = 4;
  let iRemark: number = 5;
  let iStartTz: number = -1;
  let iEndTz: number = -1;
  let startRow: number = 0;

  if (sheet.rows.length > 0) {
    const head = sheet.rows[0];
    const find = (name: string): number => {
      let found: number = -1;
      head.forEach((v: string, k: number) => {
        if (v.trim() === name) {
          found = k;
        }
      });
      return found;
    };
    const a = find('开始时间');
    if (a >= 0) {
      iStart = a;
      iEnd = find('结束时间');
      iStatus = find('状态');
      iRemark = find('备注');
      iStartTz = find('开始时区');
      iEndTz = find('结束时区');
      startRow = 1;
      if (iEnd < 0 || iStatus < 0) {
        res.errors.push('「时间区间明细」表头缺少 结束时间 / 状态 列');
        return;
      }
    }
  }

  for (let r: number = startRow; r < sheet.rows.length; r++) {
    const row = sheet.rows[r];
    const at = (idx: number): string => idx < 0 ? '' : (row.get(idx) ?? '');
    const lineNo: number = r + 1;

    if (at(iStart).trim().length === 0 && at(iEnd).trim().length === 0) {
      continue;
    }
    const startWall: number = cellToWall(at(iStart));
    const endWall: number = cellToWall(at(iEnd));
    if (isNaN(startWall) || isNaN(endWall)) {
      res.errors.push(`第 ${lineNo} 行：时间格式无法识别`);
      continue;
    }
    const status = statusOf(at(iStatus));
    if (status === null) {
      res.errors.push(`第 ${lineNo} 行：状态无法识别（${at(iStatus)}）`);
      continue;
    }
    const so: number = iStartTz >= 0 && at(iStartTz).length > 0
      ? offsetOf(at(iStartTz)) : localOffsetMin(startWall);
    const eo: number = iEndTz >= 0 && at(iEndTz).length > 0
      ? offsetOf(at(iEndTz)) : localOffsetMin(endWall);

    const start: number = startWall - so * 60000;
    const end: number = endWall - eo * 60000;
    if (end <= start) {
      res.errors.push(`第 ${lineNo} 行：结束时间必须晚于开始时间`);
      continue;
    }
    res.records.push({
      id: newId() + r,
      start: start,
      end: end,
      status: status,
      remark: at(iRemark).trim(),
      so: so,
      eo: eo
    });
  }
}

function offsetOf(text: string): number {
  const t: string = text.trim().toUpperCase().replace('GMT', 'UTC');
  const m = t.match(/^UTC\s*([+-])?\s*(\d{1,2})(?::?(\d{2}))?$/);
  if (m === null) {
    return 0;
  }
  const sign: number = m[1] === '-' ? -1 : 1;
  return sign * (parseInt(m[2]) * 60 + (m[3] ? parseInt(m[3]) : 0));
}

function mapVoyage(sheet: ImportedSheet, res: ExcelImportResult): void {
  for (let r: number = 1; r < sheet.rows.length; r++) {
    const row = sheet.rows[r];
    const key: string = (row.get(0) ?? '').trim();
    const val: string = (row.get(1) ?? '').trim();
    if (key.length === 0) {
      continue;
    }
    if (key === '航次名称') {
      res.voyageName = val;
    } else if (key.indexOf('以下为计算结果') >= 0) {
      break;
    } else if (key === '上次抵港时间') {
      res.voyageTimes[0] = cellToWall(val);
    } else if (key === '上次离港时间') {
      res.voyageTimes[1] = cellToWall(val);
    } else if (key === '本次抵港时间') {
      res.voyageTimes[2] = cellToWall(val);
    } else if (key === '上次抵港存油(吨)') {
      res.oils[0] = numOrNeg(val);
    } else if (key === '上次离港存油(吨)') {
      res.oils[1] = numOrNeg(val);
    } else if (key === '本次抵港存油(吨)') {
      res.oils[2] = numOrNeg(val);
    } else if (key === '燃油添加量(吨)') {
      res.oils[3] = numOrNeg(val);
    } else if (key === '燃油驳出量(吨)') {
      res.oils[4] = numOrNeg(val);
    }
  }
}

function mapRates(sheet: ImportedSheet, res: ExcelImportResult): void {
  for (let r: number = 1; r < sheet.rows.length; r++) {
    const row = sheet.rows[r];
    const name: string = (row.get(0) ?? '').trim();
    const val: string = (row.get(1) ?? '').trim();
    const status = statusOf(name);
    if (status === null) {
      continue;
    }
    const n: number = Number(val);
    if (!isNaN(n) && val.length > 0) {
      res.rates.set(status, n);
    }
  }
}
