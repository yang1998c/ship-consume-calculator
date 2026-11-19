/**
 * CSV 导入 / 模板导出
 *
 * 列：开始时间,开始时区,结束时间,结束时区,状态,备注
 * 时间格式：YYYY-MM-DD HH:mm[:ss]（也接受 / 分隔）
 * 时区：UTC+8 / UTC-3:30 / GMT+8 / +8，留空按本机时区
 * 状态：航行/锚泊/漂航/靠泊/系浮筒（也接受 sailing 等英文键）
 */
import { NO_OFFSET, ShipRecord, ShipStatus } from './Types';
import { localOffsetMin, wallToMs } from './Calc';

export const CSV_HEADER: string =
  '开始时间,开始时区,结束时间,结束时区,状态,备注';

export const CSV_TEMPLATE: string =
  CSV_HEADER + '\n' +
  '2026-11-19 08:00:00,UTC+8,2026-11-19 12:00:00,UTC+8,航行,上海→宁波（示例行，可删除）\n' +
  '2026-11-19 12:00:00,UTC+8,2026-11-19 18:00:00,UTC+8,锚泊,等泊（示例行，可删除）\n' +
  '2026-11-19 18:00:00,UTC+8,2026-11-20 02:00:00,UTC+9,航行,跨时区示例：拨钟 +1 小时\n';

export class CsvImportResult {
  records: ShipRecord[] = [];
  errors: string[] = [];
}

function splitCsvLine(line: string): string[] {
  const out: string[] = [];
  let cur: string = '';
  let inQuotes: boolean = false;
  for (let i: number = 0; i < line.length; i++) {
    const ch: string = line.charAt(i);
    if (inQuotes) {
      if (ch === '"') {
        if (i + 1 < line.length && line.charAt(i + 1) === '"') {
          cur += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cur += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === ',') {
      out.push(cur);
      cur = '';
    } else {
      cur += ch;
    }
  }
  out.push(cur);
  return out;
}

/** 船钟墙钟文本 -> 朴素毫秒；失败返回 NaN */
export function parseWallText(text: string): number {
  const t: string = text.trim().replace(/\//g, '-');
  const m = t.match(/^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$/);
  if (m === null) {
    return NaN;
  }
  return wallToMs(parseInt(m[1]), parseInt(m[2]), parseInt(m[3]),
    parseInt(m[4]), parseInt(m[5]), m[6] ? parseInt(m[6]) : 0);
}

/** "UTC+8" / "GMT-3:30" / "+8" -> 偏移分钟；无法识别返回 NO_OFFSET */
export function parseOffsetText(text: string): number {
  const t: string = text.trim().toUpperCase().replace('GMT', 'UTC');
  if (t.length === 0) {
    return NO_OFFSET;
  }
  const m = t.match(/^UTC\s*([+-])?\s*(\d{1,2})(?::?(\d{2}))?$/);
  if (m === null) {
    return NO_OFFSET;
  }
  const sign: number = m[1] === '-' ? -1 : 1;
  return sign * (parseInt(m[2]) * 60 + (m[3] ? parseInt(m[3]) : 0));
}

function statusOf(text: string): ShipStatus | null {
  const t: string = text.trim();
  switch (t) {
    case '航行': case 'sailing': return ShipStatus.Sailing;
    case '锚泊': case 'anchorage': return ShipStatus.Anchorage;
    case '漂航': case 'drifting': return ShipStatus.Drifting;
    case '靠泊': case 'berthing': return ShipStatus.Berthing;
    case '系浮筒': case 'buoy': return ShipStatus.Buoy;
    default: return null;
  }
}

function newId(): string {
  return Date.now().toString(36) + Math.floor(Math.random() * 100000).toString(36);
}

export function parseCsv(text: string): CsvImportResult {
  const res = new CsvImportResult();
  // 去 BOM，兼容 CRLF
  const body: string = text.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines: string[] = body.split('\n');

  // 列索引：默认按模板位置，遇到表头则按列名重排（兼容本应用导出的 CSV，
  // 其中多了「序号」「时长(小时)」两列）
  let iStart: number = 0;
  let iStartTz: number = 1;
  let iEnd: number = 2;
  let iEndTz: number = 3;
  let iStatus: number = 4;
  let iRemark: number = 5;
  let headerSeen: boolean = false;

  for (let i: number = 0; i < lines.length; i++) {
    const raw: string = lines[i];
    if (raw.trim().length === 0 || raw.trim().startsWith('#')) {
      continue;
    }
    const cells: string[] = splitCsvLine(raw);

    if (!headerSeen && cells.length > 0 && cells[0].indexOf('开始时间') >= 0) {
      headerSeen = true;
      const find = (name: string): number => {
        for (let k: number = 0; k < cells.length; k++) {
          if (cells[k].trim() === name) {
            return k;
          }
        }
        return -1;
      };
      const a = find('开始时间');
      const b = find('结束时间');
      const c = find('状态');
      if (a < 0 || b < 0 || c < 0) {
        res.errors.push('表头缺少必需列：开始时间 / 结束时间 / 状态');
        return res;
      }
      iStart = a;
      iEnd = b;
      iStatus = c;
      const tza = find('开始时区');
      const tzb = find('结束时区');
      const rm = find('备注');
      iStartTz = tza;
      iEndTz = tzb;
      iRemark = rm;
      continue;
    }
    headerSeen = true;

    const lineNo: number = i + 1;
    const need: number = Math.max(iStart, iEnd, iStatus) + 1;
    if (cells.length < need) {
      res.errors.push(`第 ${lineNo} 行：列数不足（需要至少 ${need} 列）`);
      continue;
    }

    const cell = (idx: number): string => (idx >= 0 && idx < cells.length) ? cells[idx] : '';

    const startWall: number = parseWallText(cell(iStart));
    const endWall: number = parseWallText(cell(iEnd));
    if (isNaN(startWall)) {
      res.errors.push(`第 ${lineNo} 行：开始时间格式不正确（${cell(iStart)}）`);
      continue;
    }
    if (isNaN(endWall)) {
      res.errors.push(`第 ${lineNo} 行：结束时间格式不正确（${cell(iEnd)}）`);
      continue;
    }

    const status = statusOf(cell(iStatus));
    if (status === null) {
      res.errors.push(`第 ${lineNo} 行：状态无法识别（${cell(iStatus)}）`);
      continue;
    }

    let so: number = parseOffsetText(cell(iStartTz));
    let eo: number = parseOffsetText(cell(iEndTz));
    if (so === NO_OFFSET) {
      so = localOffsetMin(startWall);
    }
    if (eo === NO_OFFSET) {
      eo = localOffsetMin(endWall);
    }

    const start: number = startWall - so * 60000;
    const end: number = endWall - eo * 60000;
    if (end <= start) {
      res.errors.push(`第 ${lineNo} 行：结束时间必须晚于开始时间`);
      continue;
    }

    res.records.push({
      id: newId() + i,
      start: start,
      end: end,
      status: status,
      remark: cell(iRemark).trim(),
      so: so,
      eo: eo
    });
  }

  return res;
}
