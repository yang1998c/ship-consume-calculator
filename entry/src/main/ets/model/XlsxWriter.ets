/**
 * 极简 XLSX 生成器（不依赖任何三方库）
 *
 * 只用 ZIP store（不压缩）+ SpreadsheetML，字符串走 inlineStr，
 * 避免 sharedStrings 与样式依赖，Excel / WPS / Numbers 均可打开。
 */
import { util } from '@kit.ArkTS';

export enum CellKind {
  TEXT = 0,
  NUMBER = 1
}

export class Cell {
  kind: CellKind = CellKind.TEXT;
  text: string = '';
  num: number = 0;

  static ofText(v: string): Cell {
    const c = new Cell();
    c.kind = CellKind.TEXT;
    c.text = v;
    return c;
  }

  static ofNum(v: number): Cell {
    const c = new Cell();
    c.kind = CellKind.NUMBER;
    c.num = v;
    return c;
  }
}

export class SheetSpec {
  name: string = '';
  rows: Cell[][] = [];
  /** 每列宽度，索引从 0 开始 */
  widths: number[] = [];
}

// ---------------- 基础编码 ----------------

function utf8(text: string): Uint8Array {
  const enc = new util.TextEncoder();
  return enc.encodeInto(text);
}

function u16(n: number): number[] {
  return [n & 0xFF, (n >>> 8) & 0xFF];
}

function u32(n: number): number[] {
  return [n & 0xFF, (n >>> 8) & 0xFF, (n >>> 16) & 0xFF, (n >>> 24) & 0xFF];
}

let crcTable: number[] | null = null;

function crc32(data: Uint8Array): number {
  if (crcTable === null) {
    const t: number[] = [];
    for (let i: number = 0; i < 256; i++) {
      let c: number = i;
      for (let k: number = 0; k < 8; k++) {
        c = (c & 1) !== 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      }
      t.push(c >>> 0);
    }
    crcTable = t;
  }
  let crc: number = 0xFFFFFFFF;
  for (let i: number = 0; i < data.length; i++) {
    crc = (crc >>> 8) ^ crcTable[(crc ^ data[i]) & 0xFF];
  }
  return (crc ^ 0xFFFFFFFF) >>> 0;
}

function xmlEscape(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&apos;');
}

function colName(index: number): string {
  let n: number = index + 1;
  let s: string = '';
  while (n > 0) {
    const m: number = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = Math.floor((n - 1) / 26);
  }
  return s;
}

// ---------------- ZIP（store） ----------------

class ZipEntry {
  name: string = '';
  data: Uint8Array = new Uint8Array(0);
  crc: number = 0;
  offset: number = 0;
}

function buildZip(entries: ZipEntry[]): Uint8Array {
  const out: number[] = [];
  const now: Date = new Date();
  const dosTime: number = ((now.getHours() << 11) | (now.getMinutes() << 5) |
    Math.floor(now.getSeconds() / 2)) & 0xFFFF;
  const dosDate: number = (((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) |
    now.getDate()) & 0xFFFF;

  for (let i: number = 0; i < entries.length; i++) {
    const e = entries[i];
    e.crc = crc32(e.data);
    e.offset = out.length;
    const nameBytes: Uint8Array = utf8(e.name);
    // local file header
    out.push(...u32(0x04034b50));
    out.push(...u16(20));
    out.push(...u16(0x0800)); // UTF-8 文件名
    out.push(...u16(0));      // store
    out.push(...u16(dosTime));
    out.push(...u16(dosDate));
    out.push(...u32(e.crc));
    out.push(...u32(e.data.length));
    out.push(...u32(e.data.length));
    out.push(...u16(nameBytes.length));
    out.push(...u16(0));
    for (let k: number = 0; k < nameBytes.length; k++) {
      out.push(nameBytes[k]);
    }
    for (let k: number = 0; k < e.data.length; k++) {
      out.push(e.data[k]);
    }
  }

  const cdStart: number = out.length;
  for (let i: number = 0; i < entries.length; i++) {
    const e = entries[i];
    const nameBytes: Uint8Array = utf8(e.name);
    out.push(...u32(0x02014b50));
    out.push(...u16(20));
    out.push(...u16(20));
    out.push(...u16(0x0800));
    out.push(...u16(0));
    out.push(...u16(dosTime));
    out.push(...u16(dosDate));
    out.push(...u32(e.crc));
    out.push(...u32(e.data.length));
    out.push(...u32(e.data.length));
    out.push(...u16(nameBytes.length));
    out.push(...u16(0));
    out.push(...u16(0));
    out.push(...u16(0));
    out.push(...u16(0));
    out.push(...u32(0));
    out.push(...u32(e.offset));
    for (let k: number = 0; k < nameBytes.length; k++) {
      out.push(nameBytes[k]);
    }
  }
  const cdSize: number = out.length - cdStart;

  out.push(...u32(0x06054b50));
  out.push(...u16(0));
  out.push(...u16(0));
  out.push(...u16(entries.length));
  out.push(...u16(entries.length));
  out.push(...u32(cdSize));
  out.push(...u32(cdStart));
  out.push(...u16(0));

  return new Uint8Array(out);
}

// ---------------- 工作表 ----------------

function sheetXml(spec: SheetSpec): string {
  const parts: string[] = [];
  parts.push('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
  parts.push('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');

  if (spec.widths.length > 0) {
    parts.push('<cols>');
    for (let i: number = 0; i < spec.widths.length; i++) {
      parts.push(`<col min="${i + 1}" max="${i + 1}" width="${spec.widths[i]}" customWidth="1"/>`);
    }
    parts.push('</cols>');
  }

  parts.push('<sheetData>');
  for (let r: number = 0; r < spec.rows.length; r++) {
    const row = spec.rows[r];
    parts.push(`<row r="${r + 1}">`);
    for (let c: number = 0; c < row.length; c++) {
      const cell = row[c];
      const ref: string = colName(c) + (r + 1);
      const style: string = r === 0 ? ' s="1"' : '';
      if (cell.kind === CellKind.NUMBER) {
        parts.push(`<c r="${ref}"${style}><v>${cell.num}</v></c>`);
      } else if (cell.text.length > 0) {
        parts.push(`<c r="${ref}"${style} t="inlineStr"><is><t xml:space="preserve">${xmlEscape(cell.text)}</t></is></c>`);
      }
    }
    parts.push('</row>');
  }
  parts.push('</sheetData></worksheet>');
  return parts.join('');
}

/** 生成 xlsx 字节 */
export function buildXlsx(sheets: SheetSpec[]): Uint8Array {
  const entries: ZipEntry[] = [];

  const push = (name: string, text: string): void => {
    const e = new ZipEntry();
    e.name = name;
    e.data = utf8(text);
    entries.push(e);
  };

  let ct: string = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>';
  for (let i: number = 0; i < sheets.length; i++) {
    ct += `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ` +
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>';
  }
  ct += '</Types>';
  push('[Content_Types].xml', ct);

  push('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" ' +
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" ' +
    'Target="xl/workbook.xml"/></Relationships>');

  let wb: string = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>';
  for (let i: number = 0; i < sheets.length; i++) {
    wb += `<sheet name="${xmlEscape(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`;
  }
  wb += '</sheets></workbook>';
  push('xl/workbook.xml', wb);

  let rels: string = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">';
  for (let i: number = 0; i < sheets.length; i++) {
    rels += `<Relationship Id="rId${i + 1}" ` +
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" ' +
      `Target="worksheets/sheet${i + 1}.xml"/>`;
  }
  rels += `<Relationship Id="rId${sheets.length + 1}" ` +
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" ' +
    'Target="styles.xml"/>';
  rels += '</Relationships>';
  push('xl/_rels/workbook.xml.rels', rels);

  push('xl/styles.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    '<fonts count="2">' +
    '<font><sz val="11"/><name val="Calibri"/></font>' +
    '<font><b/><sz val="11"/><name val="Calibri"/></font>' +
    '</fonts>' +
    '<fills count="2"><fill><patternFill patternType="none"/></fill>' +
    '<fill><patternFill patternType="gray125"/></fill></fills>' +
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
    '<cellXfs count="2">' +
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>' +
    '</cellXfs>' +
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' +
    '</styleSheet>');

  for (let i: number = 0; i < sheets.length; i++) {
    push(`xl/worksheets/sheet${i + 1}.xml`, sheetXml(sheets[i]));
  }

  return buildZip(entries);
}
