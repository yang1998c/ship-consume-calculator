/**
 * 船舶能耗计算器 —— 持久化 / 备份 / 导出
 */
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import {
  FuelRates, NO_OFFSET, NO_TIME, ShipRecord, ShipStatus, VoyageInfo, emptyVoyage
} from './Types';
import { floorToMinute, formatInZone, fmtOffset, pad2, recordEndOff, recordStartOff } from './Calc';

export const KEY_RECORDS: string = 'ship_energy_records';
export const KEY_RATES: string = 'ship_energy_rates';
export const KEY_VOYAGE: string = 'ship_energy_voyage';
export const KEY_THEME: string = 'ship_energy_theme';
export const KEY_NOON: string = 'ship_energy_noon';

export function newId(): string {
  return Date.now().toString(36) + Math.floor(Math.random() * 100000).toString(36);
}

interface RawRecord {
  id?: string;
  start?: number;
  end?: number;
  status?: string;
  remark?: string;
  so?: number;
  eo?: number;
}

function isStatus(s: string): boolean {
  return s === 'sailing' || s === 'anchorage' || s === 'drifting' || s === 'berthing' || s === 'buoy';
}

function statusOf(s: string): ShipStatus {
  switch (s) {
    case 'anchorage': return ShipStatus.Anchorage;
    case 'drifting': return ShipStatus.Drifting;
    case 'berthing': return ShipStatus.Berthing;
    case 'buoy': return ShipStatus.Buoy;
    default: return ShipStatus.Sailing;
  }
}

export function encodeRecords(list: ShipRecord[]): string {
  return JSON.stringify(list);
}

export function decodeRecords(json: string): ShipRecord[] {
  const out: ShipRecord[] = [];
  if (json === undefined || json === null || json.length === 0) {
    return out;
  }
  try {
    const arr = JSON.parse(json) as RawRecord[];
    if (!Array.isArray(arr)) {
      return out;
    }
    for (let i: number = 0; i < arr.length; i++) {
      const r = arr[i];
      if (r === null || r === undefined) {
        continue;
      }
      const start: number = typeof r.start === 'number' ? r.start : NO_TIME;
      const end: number = typeof r.end === 'number' ? r.end : NO_TIME;
      const st: string = typeof r.status === 'string' ? r.status : '';
      if (start === NO_TIME || end === NO_TIME || !isStatus(st)) {
        continue;
      }
      const rec: ShipRecord = {
        id: typeof r.id === 'string' && r.id.length > 0 ? r.id : newId(),
        start: floorToMinute(start),
        end: floorToMinute(end),
        status: statusOf(st),
        remark: typeof r.remark === 'string' ? r.remark : '',
        so: typeof r.so === 'number' ? Math.round(r.so) : NO_OFFSET,
        eo: typeof r.eo === 'number' ? Math.round(r.eo) : NO_OFFSET
      };
      out.push(rec);
    }
  } catch (e) {
    return [];
  }
  return out;
}

export function encodeRates(r: FuelRates): string {
  return JSON.stringify(r);
}

export function decodeRates(json: string): FuelRates {
  const def = new FuelRates();
  if (json === undefined || json === null || json.length === 0) {
    return def;
  }
  try {
    const raw = JSON.parse(json) as RawRates;
    const r = new FuelRates();
    r.sailing = typeof raw.sailing === 'number' ? raw.sailing : def.sailing;
    r.anchorage = typeof raw.anchorage === 'number' ? raw.anchorage : def.anchorage;
    r.drifting = typeof raw.drifting === 'number' ? raw.drifting : def.drifting;
    r.berthing = typeof raw.berthing === 'number' ? raw.berthing : def.berthing;
    r.buoy = typeof raw.buoy === 'number' ? raw.buoy : def.buoy;
    return r;
  } catch (e) {
    return def;
  }
}

interface RawRates {
  sailing?: number;
  anchorage?: number;
  drifting?: number;
  berthing?: number;
  buoy?: number;
}

interface RawVoyage {
  name?: string;
  lastArrival?: number;
  lastDeparture?: number;
  thisArrival?: number;
  oilLastArrival?: number;
  oilLastDeparture?: number;
  oilThisArrival?: number;
  oilAdded?: number;
  oilTransferred?: number;
}

export function encodeVoyage(v: VoyageInfo): string {
  return JSON.stringify(v);
}

export function decodeVoyage(json: string): VoyageInfo {
  const v = emptyVoyage();
  if (json === undefined || json === null || json.length === 0) {
    return v;
  }
  try {
    const raw = JSON.parse(json) as RawVoyage;
    v.name = typeof raw.name === 'string' ? raw.name : '';
    v.lastArrival = typeof raw.lastArrival === 'number' ? raw.lastArrival : NO_TIME;
    v.lastDeparture = typeof raw.lastDeparture === 'number' ? raw.lastDeparture : NO_TIME;
    v.thisArrival = typeof raw.thisArrival === 'number' ? raw.thisArrival : NO_TIME;
    v.oilLastArrival = typeof raw.oilLastArrival === 'number' ? raw.oilLastArrival : -1;
    v.oilLastDeparture = typeof raw.oilLastDeparture === 'number' ? raw.oilLastDeparture : -1;
    v.oilThisArrival = typeof raw.oilThisArrival === 'number' ? raw.oilThisArrival : -1;
    v.oilAdded = typeof raw.oilAdded === 'number' ? raw.oilAdded : -1;
    v.oilTransferred = typeof raw.oilTransferred === 'number' ? raw.oilTransferred : -1;
  } catch (e) {
    return emptyVoyage();
  }
  return v;
}

// ---------------- 备份 ----------------

export interface BackupPayload {
  app: string;
  version: number;
  exportedAt: string;
  records: ShipRecord[];
  rates: FuelRates;
  voyage: VoyageInfo;
}

export interface RestoreResult {
  ok: boolean;
  message: string;
  records: ShipRecord[];
  rates: FuelRates;
  voyage: VoyageInfo;
}

export function fileStamp(): string {
  const d = new Date();
  return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}-` +
    `${pad2(d.getHours())}${pad2(d.getMinutes())}`;
}

export function buildBackup(records: ShipRecord[], rates: FuelRates, voyage: VoyageInfo): string {
  const payload: BackupPayload = {
    app: 'ship-energy-calculator',
    version: 1,
    exportedAt: new Date().toISOString(),
    records: records,
    rates: rates,
    voyage: voyage
  };
  return JSON.stringify(payload);
}

export function parseBackup(text: string): RestoreResult {
  const res: RestoreResult = {
    ok: false,
    message: '',
    records: [],
    rates: new FuelRates(),
    voyage: emptyVoyage()
  };
  let payload: BackupPayload;
  try {
    payload = JSON.parse(text) as BackupPayload;
  } catch (e) {
    res.message = '备份文件无法解析，请确认是本软件保存的 .json 备份';
    return res;
  }
  if (payload === null || payload === undefined || !Array.isArray(payload.records)) {
    res.message = '备份文件格式不正确（缺少 records 数据）';
    return res;
  }
  const decoded = decodeRecords(JSON.stringify(payload.records));
  res.records = decoded;
  res.rates = decodeRates(JSON.stringify(payload.rates));
  res.voyage = decodeVoyage(JSON.stringify(payload.voyage));
  res.ok = true;
  res.message = `备份已恢复：时间区间 ${decoded.length} 条`;
  return res;
}

// ---------------- CSV 导出 ----------------

function csvCell(s: string): string {
  if (s.indexOf(',') >= 0 || s.indexOf('"') >= 0 || s.indexOf('\n') >= 0) {
    return '"' + s.replace(/"/g, '""') + '"';
  }
  return s;
}

// ---------------- 文件读写 ----------------

export async function saveTextFile(ctx: common.UIAbilityContext, fileName: string, content: string): Promise<string> {
  const options = new picker.DocumentSaveOptions();
  options.newFileNames = [fileName];
  const viewPicker = new picker.DocumentViewPicker(ctx);
  const uris = await viewPicker.save(options);
  if (uris.length === 0) {
    return '';
  }
  const uri: string = uris[0];
  const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  fs.writeSync(file.fd, content);
  fs.closeSync(file);
  return uri;
}

/** 保存二进制文件（xlsx 等）到用户选择的位置 */
export async function saveBinaryFile(ctx: common.UIAbilityContext, fileName: string,
  data: Uint8Array): Promise<string> {
  const options = new picker.DocumentSaveOptions();
  options.newFileNames = [fileName];
  const viewPicker = new picker.DocumentViewPicker(ctx);
  const uris = await viewPicker.save(options);
  if (uris.length === 0) {
    return '';
  }
  const uri: string = uris[0];
  const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    const buf: ArrayBuffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer;
    fs.writeSync(file.fd, buf);
  } finally {
    fs.closeSync(file);
  }
  return uri;
}

/** 只返回选中的文件 URI（用于 xlsx 这类需要自行解析的二进制文件） */
export async function pickFileUri(ctx: common.UIAbilityContext, suffix: string): Promise<string> {
  const options = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 1;
  options.fileSuffixFilters = [suffix];
  const viewPicker = new picker.DocumentViewPicker(ctx);
  const uris = await viewPicker.select(options);
  return uris.length === 0 ? '' : uris[0];
}

export async function pickTextFile(ctx: common.UIAbilityContext, suffix: string): Promise<string> {
  const options = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 1;
  options.fileSuffixFilters = [suffix];
  const viewPicker = new picker.DocumentViewPicker(ctx);
  const uris = await viewPicker.select(options);
  if (uris.length === 0) {
    return '';
  }
  // 注意：picker 返回的是 file://docs/... 形式的 URI，
  // fs.readTextSync 只接受应用沙箱路径，必须用 fd 读取。
  const uri: string = uris[0];
  const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  try {
    const stat = fs.statSync(file.fd);
    if (stat.size <= 0) {
      return '';
    }
    const buffer = new ArrayBuffer(stat.size);
    const readLen: number = fs.readSync(file.fd, buffer);
    if (readLen <= 0) {
      return '';
    }
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(buffer.slice(0, readLen)));
  } finally {
    fs.closeSync(file);
  }
}
