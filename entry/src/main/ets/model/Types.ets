/**
 * 船舶能耗计算器 —— 数据模型
 *
 * 时间约定：
 *  - 记录以绝对时间戳(ms, UTC)存储，so/eo 为开始/结束「船钟」相对 UTC 的偏移（分钟，15 分钟粒度）。
 *  - 航次 / 正午输入框使用「船钟墙钟」的朴素毫秒（按 UTC 锚定），只参与同口径比较与运算。
 */

/** 未设置的时间 / 偏移哨兵值（避免 null 联合类型，便于 JSON 往返） */
export const NO_OFFSET: number = -32768;
export const NO_TIME: number = -1;

export enum ShipStatus {
  Sailing = 'sailing',
  Anchorage = 'anchorage',
  Drifting = 'drifting',
  Berthing = 'berthing',
  Buoy = 'buoy'
}

export interface StatusMeta {
  key: ShipStatus;
  name: string;
  en: string;
}

export const STATUS_LIST: StatusMeta[] = [
  { key: ShipStatus.Sailing, name: '航行', en: 'Sailing' },
  { key: ShipStatus.Anchorage, name: '锚泊', en: 'Anchorage' },
  { key: ShipStatus.Drifting, name: '漂航', en: 'Drifting' },
  { key: ShipStatus.Berthing, name: '靠泊', en: 'Berthing' },
  { key: ShipStatus.Buoy, name: '系浮筒', en: 'Buoy' }
];

/** 时间区间记录 */
export interface ShipRecord {
  id: string;
  /** 绝对开始时间戳 */
  start: number;
  /** 绝对结束时间戳 */
  end: number;
  status: ShipStatus;
  remark: string;
  /** 开始端船钟 UTC 偏移（分钟）；NO_OFFSET 表示未知（按本机时区解释） */
  so: number;
  /** 结束端船钟 UTC 偏移（分钟） */
  eo: number;
}

/** 航次信息（时间均为船钟墙钟朴素毫秒，NO_TIME 表示未填） */
export interface VoyageInfo {
  name: string;
  lastArrival: number;
  lastDeparture: number;
  thisArrival: number;
  oilLastArrival: number;
  oilLastDeparture: number;
  oilThisArrival: number;
  oilAdded: number;
  oilTransferred: number;
}

export function emptyVoyage(): VoyageInfo {
  return {
    name: '',
    lastArrival: NO_TIME,
    lastDeparture: NO_TIME,
    thisArrival: NO_TIME,
    oilLastArrival: -1,
    oilLastDeparture: -1,
    oilThisArrival: -1,
    oilAdded: -1,
    oilTransferred: -1
  };
}

/** 各状态时长汇总 */
export class StatusTotals {
  sailing: number = 0;
  anchorage: number = 0;
  drifting: number = 0;
  berthing: number = 0;
  buoy: number = 0;

  get(key: ShipStatus): number {
    switch (key) {
      case ShipStatus.Sailing: return this.sailing;
      case ShipStatus.Anchorage: return this.anchorage;
      case ShipStatus.Drifting: return this.drifting;
      case ShipStatus.Berthing: return this.berthing;
      case ShipStatus.Buoy: return this.buoy;
      default: return 0;
    }
  }

  add(key: ShipStatus, ms: number): void {
    switch (key) {
      case ShipStatus.Sailing: this.sailing += ms; break;
      case ShipStatus.Anchorage: this.anchorage += ms; break;
      case ShipStatus.Drifting: this.drifting += ms; break;
      case ShipStatus.Berthing: this.berthing += ms; break;
      case ShipStatus.Buoy: this.buoy += ms; break;
      default: break;
    }
  }

  total(): number {
    return this.sailing + this.anchorage + this.drifting + this.berthing + this.buoy;
  }

  clone(): StatusTotals {
    const t = new StatusTotals();
    t.sailing = this.sailing;
    t.anchorage = this.anchorage;
    t.drifting = this.drifting;
    t.berthing = this.berthing;
    t.buoy = this.buoy;
    return t;
  }
}

/** 油耗率（吨/小时），按状态 */
export class FuelRates {
  sailing: number = 0.80;
  anchorage: number = 0.10;
  drifting: number = 0.20;
  berthing: number = 0.05;
  buoy: number = 0.10;

  get(key: ShipStatus): number {
    switch (key) {
      case ShipStatus.Sailing: return this.sailing;
      case ShipStatus.Anchorage: return this.anchorage;
      case ShipStatus.Drifting: return this.drifting;
      case ShipStatus.Berthing: return this.berthing;
      case ShipStatus.Buoy: return this.buoy;
      default: return 0;
    }
  }

  set(key: ShipStatus, v: number): void {
    switch (key) {
      case ShipStatus.Sailing: this.sailing = v; break;
      case ShipStatus.Anchorage: this.anchorage = v; break;
      case ShipStatus.Drifting: this.drifting = v; break;
      case ShipStatus.Berthing: this.berthing = v; break;
      case ShipStatus.Buoy: this.buoy = v; break;
      default: break;
    }
  }

  clone(): FuelRates {
    const r = new FuelRates();
    r.sailing = this.sailing;
    r.anchorage = this.anchorage;
    r.drifting = this.drifting;
    r.berthing = this.berthing;
    r.buoy = this.buoy;
    return r;
  }
}

/** 航次核算结果 */
export class VoyageResult {
  /** 时间节点齐全且顺序合法 */
  ok: boolean = false;
  sailMs: number = NO_TIME;
  opMs: number = NO_TIME;
  portMs: number = NO_TIME;
  sums: StatusTotals = new StatusTotals();
  /** 燃油实际消耗（吨）；-1 表示数据不足 */
  fuel: number = -1;
  fuelReady: boolean = false;
  /** 校验提示 */
  warns: string[] = [];
  /** 窗口内被区间覆盖的毫秒数 */
  coveredMs: number = 0;
  matched: number = 0;
}

/** 正午分段 */
export class NoonSegment {
  startAbs: number = 0;
  endAbs: number = 0;
  startOff: number = 0;
  endOff: number = 0;
  sums: StatusTotals = new StatusTotals();
  coveredMs: number = 0;
  gapMs: number = 0;
}

export class NoonResult {
  valid: boolean = false;
  message: string = '';
  tooMany: boolean = false;
  segments: NoonSegment[] = [];
  grand: StatusTotals = new StatusTotals();
  grandCovered: number = 0;
  rangeMs: number = 0;
  startAbs: number = 0;
  endAbs: number = 0;
  startOff: number = 0;
  endOff: number = 0;
  overlap: boolean = false;
}
