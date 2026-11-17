/**
 * 船舶能耗计算器 —— 本地存储（应用沙箱单文件 JSON）
 */
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { FuelRates, NO_TIME, ShipRecord, VoyageInfo, emptyVoyage } from './Types';
import { decodeRates, decodeRecords, decodeVoyage } from './Store';

const FILE_NAME: string = 'ship_energy_data.json';

export class AppData {
  records: ShipRecord[] = [];
  rates: FuelRates = new FuelRates();
  voyage: VoyageInfo = emptyVoyage();
  noonStart: number = NO_TIME;
  noonEnd: number = NO_TIME;
  dark: boolean = false;
  /** 是否已同意用户协议与隐私政策 */
  privacyAgreed: boolean = false;
}

interface RawAppData {
  records?: object;
  rates?: object;
  voyage?: object;
  noonStart?: number;
  noonEnd?: number;
  dark?: boolean;
  privacyAgreed?: boolean;
}

function dataPath(ctx: common.Context): string {
  return ctx.filesDir + '/' + FILE_NAME;
}

export function loadAppData(ctx: common.Context): AppData {
  const data = new AppData();
  const path = dataPath(ctx);
  try {
    if (!fs.accessSync(path)) {
      return data;
    }
    const text = fs.readTextSync(path);
    if (text.length === 0) {
      return data;
    }
    const raw = JSON.parse(text) as RawAppData;
    if (raw.records !== undefined && raw.records !== null) {
      data.records = decodeRecords(JSON.stringify(raw.records));
    }
    if (raw.rates !== undefined && raw.rates !== null) {
      data.rates = decodeRates(JSON.stringify(raw.rates));
    }
    if (raw.voyage !== undefined && raw.voyage !== null) {
      data.voyage = decodeVoyage(JSON.stringify(raw.voyage));
    }
    data.noonStart = typeof raw.noonStart === 'number' ? raw.noonStart : NO_TIME;
    data.noonEnd = typeof raw.noonEnd === 'number' ? raw.noonEnd : NO_TIME;
    data.dark = raw.dark === true;
    data.privacyAgreed = raw.privacyAgreed === true;
  } catch (e) {
    return new AppData();
  }
  return data;
}

export function saveAppData(ctx: common.Context, data: AppData): void {
  const path = dataPath(ctx);
  const payload: RawAppData = {
    records: data.records,
    rates: data.rates,
    voyage: data.voyage,
    noonStart: data.noonStart,
    noonEnd: data.noonEnd,
    dark: data.dark,
    privacyAgreed: data.privacyAgreed
  };
  const text = JSON.stringify(payload);
  const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  fs.writeSync(file.fd, text);
  fs.closeSync(file);
}
