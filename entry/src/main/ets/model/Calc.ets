/**
 * 船舶能耗计算器 —— 计算与格式化（纯函数，无 UI 依赖）
 */
import {
  FuelRates, NoonResult, NoonSegment, NO_OFFSET, NO_TIME, ShipRecord, ShipStatus, STATUS_LIST,
  StatusTotals, VoyageInfo, VoyageResult
} from './Types';

const MS_MIN: number = 60000;
const MS_HOUR: number = 3600000;
const MS_DAY: number = 86400000;

export function pad2(n: number): string {
  return n < 10 ? '0' + n : '' + n;
}

// ---------------- 时长格式化 ----------------

export class DurInfo {
  days: number = 0;
  hours: number = 0;
  minutes: number = 0;
  seconds: number = 0;
  totalHours: number = 0;
  text: string = '';
}

/** 毫秒 -> 天/时/分/秒 及中文可读文本 */
export function fmtDuration(ms: number): DurInfo {
  const totalSec: number = Math.round(ms / 1000);
  const days: number = Math.floor(totalSec / 86400);
  const hours: number = Math.floor((totalSec % 86400) / 3600);
  const minutes: number = Math.floor((totalSec % 3600) / 60);
  const seconds: number = totalSec % 60;
  const parts: string[] = [];
  if (days > 0) {
    parts.push(days + ' 天');
  }
  if (hours > 0) {
    parts.push(hours + ' 小时');
  }
  if (minutes > 0) {
    parts.push(minutes + ' 分');
  }
  if (parts.length === 0) {
    parts.push('不足 1 分');
  }
  const info = new DurInfo();
  info.days = days;
  info.hours = hours;
  info.minutes = minutes;
  info.seconds = seconds;
  info.totalHours = totalSec / 3600;
  info.text = parts.join(' ');
  return info;
}

/** 把绝对时间戳向下取整到分钟（应用内时间精度统一到分钟） */
export function floorToMinute(ms: number): number {
  return Math.floor(ms / 60000) * 60000;
}

/** 毫秒 -> 累计小时:分钟（hh:mm），如 96:00、3:30 */
export function fmtHM(ms: number): string {
  const totalMin: number = Math.round(ms / MS_MIN);
  const h: number = Math.floor(totalMin / 60);
  const m: number = totalMin % 60;
  return h + ':' + pad2(m);
}

// ---------------- 时区 ----------------

/** 可选 UTC 偏移（分钟）：-12:00 ～ +14:00，整点 / :30 / :45 */
function buildTzOffsets(): number[] {
  const list: number[] = [];
  for (let m: number = -720; m <= 840; m += 15) {
    const r: number = ((m % 60) + 60) % 60;
    if (r === 0 || r === 30 || r === 45) {
      list.push(m);
    }
  }
  return list;
}

export const TZ_OFFSETS: number[] = buildTzOffsets();

/** 偏移分钟 -> "UTC+8" / "UTC−3:30" */
export function fmtOffset(min: number): string {
  const sign: string = min < 0 ? '−' : '+';
  const a: number = Math.abs(min);
  const mm: number = a % 60;
  return 'UTC' + sign + Math.floor(a / 60) + (mm > 0 ? ':' + pad2(mm) : '');
}

/** 偏移的短标签，用于下拉框 */
export function offsetLabel(min: number): string {
  return fmtOffset(min);
}

/** 吸附到可用档位 */
export function snapOffset(off: number): number {
  let best: number = TZ_OFFSETS[0];
  let bd: number = Infinity;
  for (let i: number = 0; i < TZ_OFFSETS.length; i++) {
    const d: number = Math.abs(TZ_OFFSETS[i] - off);
    if (d < bd) {
      bd = d;
      best = TZ_OFFSETS[i];
    }
  }
  return best;
}

/** 本机当前 UTC 偏移（分钟），吸附到可选档位 */
export function localOffsetMin(atMs: number): number {
  const t: number = atMs > 0 ? atMs : Date.now();
  const off: number = -new Date(t).getTimezoneOffset();
  return snapOffset(off);
}

/** 记录某一端生效的偏移 */
export function recordStartOff(r: ShipRecord): number {
  return r.so === NO_OFFSET ? localOffsetMin(r.start) : r.so;
}

export function recordEndOff(r: ShipRecord): number {
  return r.eo === NO_OFFSET ? localOffsetMin(r.end) : r.eo;
}

// ---------------- 墙钟（船钟）工具 ----------------

export function wallToMs(y: number, mo: number, d: number, h: number, mi: number, s: number): number {
  return Date.UTC(y, mo - 1, d, h, mi, s);
}

export interface WallParts {
  y: number;
  mo: number;
  d: number;
  h: number;
  mi: number;
  s: number;
}

export function partsOfWall(wallMs: number): WallParts {
  const d = new Date(wallMs);
  const p: WallParts = {
    y: d.getUTCFullYear(),
    mo: d.getUTCMonth() + 1,
    d: d.getUTCDate(),
    h: d.getUTCHours(),
    mi: d.getUTCMinutes(),
    s: d.getUTCSeconds()
  };
  return p;
}

/** 墙钟毫秒 -> "YYYY-MM-DD HH:mm"（精确到分钟） */
export function formatWall(wallMs: number): string {
  const p = partsOfWall(wallMs);
  return `${p.y}-${pad2(p.mo)}-${pad2(p.d)} ${pad2(p.h)}:${pad2(p.mi)}`;
}

/** 墙钟毫秒 -> "MM-DD HH:mm" */
export function formatWallShort(wallMs: number): string {
  const p = partsOfWall(wallMs);
  return `${pad2(p.mo)}-${pad2(p.d)} ${pad2(p.h)}:${pad2(p.mi)}`;
}

/** 绝对时间戳按指定船钟偏移格式化为 "YYYY-MM-DD HH:mm"（精确到分钟） */
export function formatInZone(ts: number, off: number): string {
  if (off === NO_OFFSET) {
    return formatWall(ts);
  }
  return formatWall(ts + off * MS_MIN);
}

/** 绝对时间戳按指定偏移格式化为 "MM-DD HH:mm" */
export function formatInZoneShort(ts: number, off: number): string {
  if (off === NO_OFFSET) {
    return formatWallShort(ts);
  }
  return formatWallShort(ts + off * MS_MIN);
}

/** 拨钟量文本，如 −1:00 / +0:30 */
export function fmtClockAdj(deltaMin: number): string {
  const sign: string = deltaMin < 0 ? '−' : '+';
  const a: number = Math.abs(deltaMin);
  return sign + Math.floor(a / 60) + ':' + pad2(a % 60);
}

/** 数值格式化：null 显示破折号 */
export function fmtTons(n: number): string {
  return n < 0 ? '—' : n.toFixed(3);
}

// ---------------- 汇总 / 油耗 ----------------

export function computeSummary(records: ShipRecord[]): StatusTotals {
  const totals = new StatusTotals();
  for (let i: number = 0; i < records.length; i++) {
    const r = records[i];
    totals.add(r.status, r.end - r.start);
  }
  return totals;
}

export class FuelRow {
  key: ShipStatus = ShipStatus.Sailing;
  name: string = '';
  hours: number = 0;
  fuel: number = 0;
}

export class FuelResult {
  rows: FuelRow[] = [];
  total: number = 0;
}

export function computeFuel(totals: StatusTotals, rates: FuelRates): FuelResult {
  const res = new FuelResult();
  for (let i: number = 0; i < STATUS_LIST.length; i++) {
    const key: ShipStatus = STATUS_LIST[i].key;
    const hours: number = totals.get(key) / MS_HOUR;
    const fuel: number = hours * rates.get(key);
    const row = new FuelRow();
    row.key = key;
    row.name = STATUS_LIST[i].name;
    row.hours = hours;
    row.fuel = fuel;
    res.rows.push(row);
    res.total += fuel;
  }
  return res;
}

// ---------------- 航次核算 ----------------

export function computeVoyage(records: ShipRecord[], v: VoyageInfo): VoyageResult {
  const res = new VoyageResult();
  const tLA: number = v.lastArrival;
  const tLD: number = v.lastDeparture;
  const tTA: number = v.thisArrival;
  const ready: boolean = tLA !== NO_TIME && tLD !== NO_TIME && tTA !== NO_TIME;

  if (ready) {
    if (tLA > tLD) {
      res.warns.push('「上次离港时间」不能早于「上次抵港时间」');
    }
    if (tLD > tTA) {
      res.warns.push('「本次抵港时间」不能早于「上次离港时间」');
    }
    if (res.warns.length === 0) {
      res.ok = true;
      res.sailMs = tTA - tLD; // 航行时间 = 本次抵港 − 上次离港
      res.opMs = tTA - tLA;   // 营运时间 = 本次抵港 − 上次抵港
      res.portMs = tLD - tLA; // 上一港在港时间 = 上次离港 − 上次抵港
    }
  }

  // 燃油实际消耗 = 上次抵港存油 + 添加量 − 驳出量 − 本次抵港存油
  if (v.oilLastArrival >= 0 && v.oilThisArrival >= 0) {
    const added: number = v.oilAdded >= 0 ? v.oilAdded : 0;
    const out: number = v.oilTransferred >= 0 ? v.oilTransferred : 0;
    res.fuel = v.oilLastArrival + added - out - v.oilThisArrival;
    res.fuelReady = true;
    if (res.fuel < 0) {
      res.warns.push('燃油实际消耗计算结果为负，请核对存油及添加 / 驳出数据');
    }
  }

  // 航次窗口 [上次抵港, 本次抵港] 内各状态汇总；跨边界区间只截取窗口内部分
  if (res.ok) {
    for (let i: number = 0; i < records.length; i++) {
      const r = records[i];
      const s: number = Math.max(r.start, tLA);
      const e: number = Math.min(r.end, tTA);
      if (e > s) {
        res.sums.add(r.status, e - s);
        res.coveredMs += (e - s);
        res.matched++;
      }
    }
  }
  return res;
}

// ---------------- 正午分段 ----------------

/** 某一绝对时刻生效的船钟偏移：记录内线性插值，记录外取最近端点，否则本机 */
export function noonOffAt(ms: number, records: ShipRecord[]): number {
  for (let i: number = 0; i < records.length; i++) {
    const r = records[i];
    if (ms >= r.start && ms < r.end) {
      const a: number = recordStartOff(r);
      const b: number = recordEndOff(r);
      if (r.end === r.start) {
        return b;
      }
      return Math.round(a + (b - a) * ((ms - r.start) / (r.end - r.start)));
    }
  }
  let best: number = localOffsetMin(ms);
  let bd: number = Infinity;
  for (let i: number = 0; i < records.length; i++) {
    const r = records[i];
    if (ms <= r.start && r.start - ms < bd) {
      bd = r.start - ms;
      best = recordStartOff(r);
    }
    if (ms >= r.end && ms - r.end < bd) {
      bd = ms - r.end;
      best = recordEndOff(r);
    }
  }
  return best;
}

/** 船钟墙钟 → 绝对时刻：g(abs)=abs+off(abs) 单调，二分反解后吸附到分钟 */
export function noonAbsForWall(wallMs: number, records: ShipRecord[]): number {
  let lo: number = wallMs - MS_DAY;
  let hi: number = wallMs + MS_DAY;
  for (let i: number = 0; i < 60; i++) {
    const mid: number = (lo + hi) / 2;
    if (mid + noonOffAt(mid, records) * MS_MIN < wallMs) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return Math.round((lo + hi) / 2 / MS_MIN) * MS_MIN;
}

/** 生成正午分段并逐段汇总 */
export function computeNoon(startWall: number, endWall: number, records: ShipRecord[]): NoonResult {
  const res = new NoonResult();
  if (startWall === NO_TIME || endWall === NO_TIME) {
    res.message = '请选择统计的起始 / 结束时间（船钟时间）';
    return res;
  }
  const start: number = noonAbsForWall(startWall, records);
  const end: number = noonAbsForWall(endWall, records);
  if (end <= start) {
    res.message = '结束时间必须晚于开始时间';
    return res;
  }
  res.startAbs = start;
  res.endAbs = end;
  res.startOff = noonOffAt(start, records);
  res.endOff = noonOffAt(end, records);
  res.rangeMs = end - start;

  // 边界为「船钟每天 12:00」，偏移随记录 so/eo 变化；拨钟日段长天然 23/25 小时
  let cur: number = start;
  const segs: NoonSegment[] = [];
  let tooMany: boolean = false;
  while (cur < end) {
    const wallCur: number = cur + noonOffAt(cur, records) * MS_MIN;
    const d = new Date(wallCur);
    d.setUTCHours(12, 0, 0, 0);
    let noonWall: number = d.getTime();
    if (noonWall <= wallCur) {
      noonWall += MS_DAY;
    }
    const segEnd: number = Math.min(noonAbsForWall(noonWall, records), end);
    if (segEnd <= cur) {
      // 船钟大幅回拨（回拨量超过到下一个正午的时长）会导致墙钟倒走，正午切分失去意义
      res.tooMany = false;
      res.message = '检测到船钟大幅回拨，无法按正午切分，请核对时间区间的时区设置';
      return res;
    }
    const seg = new NoonSegment();
    seg.startAbs = cur;
    seg.endAbs = segEnd;
    seg.startOff = noonOffAt(cur, records);
    seg.endOff = noonOffAt(segEnd, records);
    segs.push(seg);
    cur = segEnd;
    if (segs.length > 400) {
      tooMany = true;
      break;
    }
  }

  if (tooMany) {
    res.tooMany = true;
    res.message = '时间跨度过长（超过 400 个正午分段），请缩小统计范围';
    return res;
  }

  const grand = new StatusTotals();
  let grandCovered: number = 0;
  for (let i: number = 0; i < segs.length; i++) {
    const seg = segs[i];
    const segMs: number = seg.endAbs - seg.startAbs;
    const sums = new StatusTotals();
    for (let j: number = 0; j < records.length; j++) {
      const r = records[j];
      const cs: number = Math.max(r.start, seg.startAbs);
      const ce: number = Math.min(r.end, seg.endAbs);
      if (ce > cs) {
        sums.add(r.status, ce - cs);
      }
    }
    seg.sums = sums;
    seg.coveredMs = sums.total();
    seg.gapMs = segMs - seg.coveredMs;
    grandCovered += seg.coveredMs;
    grand.sailing += sums.sailing;
    grand.anchorage += sums.anchorage;
    grand.drifting += sums.drifting;
    grand.berthing += sums.berthing;
    grand.buoy += sums.buoy;
    if (seg.gapMs < -1000) {
      res.overlap = true;
    }
  }

  res.valid = true;
  res.segments = segs;
  res.grand = grand;
  res.grandCovered = grandCovered;
  return res;
}
