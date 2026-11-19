/**
 * 船舶能耗统计 Excel（.xlsx）导出
 *
 * 工作表结构与既有报表一致：
 *   时间区间明细 / 航次统计 / 时间汇总 / 油耗参数
 */
import { Cell, SheetSpec } from './XlsxWriter';
import {
  computeSummary, computeVoyage, fmtDuration, fmtHM, formatInZone, recordEndOff, recordStartOff
} from './Calc';
import { FuelRates, NO_TIME, ShipRecord, STATUS_LIST, VoyageInfo } from './Types';

function statusName(records: ShipRecord[]): Map<string, string> {
  const m = new Map<string, string>();
  for (let i: number = 0; i < STATUS_LIST.length; i++) {
    m.set(STATUS_LIST[i].key, STATUS_LIST[i].name);
  }
  return m;
}

function text(v: string): Cell {
  return Cell.ofText(v);
}

function num(v: number): Cell {
  return Cell.ofNum(v);
}

function sorted(records: ShipRecord[]): ShipRecord[] {
  const list: ShipRecord[] = records.slice();
  list.sort((a: ShipRecord, b: ShipRecord) => a.start - b.start);
  return list;
}

/** 时间区间明细 */
function detailSheet(records: ShipRecord[], names: Map<string, string>): SheetSpec {
  const spec = new SheetSpec();
  spec.name = '时间区间明细';
  spec.widths = [6, 21, 21, 11, 9, 22];
  spec.rows.push([text('序号'), text('开始时间'), text('结束时间'),
    text('时长(小时)'), text('状态'), text('备注')]);

  const list: ShipRecord[] = sorted(records);
  for (let i: number = 0; i < list.length; i++) {
    const r: ShipRecord = list[i];
    const name: string = names.get(r.status) ?? '';
    spec.rows.push([
      num(i + 1),
      text(formatInZone(r.start, recordStartOff(r))),
      text(formatInZone(r.end, recordEndOff(r))),
      num(Math.round((r.end - r.start) / 36000) / 100),
      text(name),
      text(r.remark)
    ]);
  }
  return spec;
}

/** 航次统计 */
function voyageSheet(records: ShipRecord[], voyage: VoyageInfo): SheetSpec {
  const spec = new SheetSpec();
  spec.name = '航次统计';
  spec.widths = [36, 24];
  spec.rows.push([text('项目'), text('内容')]);

  const t = (v: number): string => v === NO_TIME ? '' : formatInZone(v, 0);
  const oil = (v: number): Cell => v >= 0 ? num(v) : text('');

  spec.rows.push([text('航次名称'), text(voyage.name)]);
  spec.rows.push([text('上次抵港时间'), text(t(voyage.lastArrival))]);
  spec.rows.push([text('上次离港时间'), text(t(voyage.lastDeparture))]);
  spec.rows.push([text('本次抵港时间'), text(t(voyage.thisArrival))]);
  spec.rows.push([text('上次抵港存油(吨)'), oil(voyage.oilLastArrival)]);
  spec.rows.push([text('上次离港存油(吨)'), oil(voyage.oilLastDeparture)]);
  spec.rows.push([text('本次抵港存油(吨)'), oil(voyage.oilThisArrival)]);
  spec.rows.push([text('燃油添加量(吨)'), oil(voyage.oilAdded)]);
  spec.rows.push([text('燃油驳出量(吨)'), oil(voyage.oilTransferred)]);

  spec.rows.push([text('—— 以下为计算结果（仅供查阅，导入时不读取）——'), text('')]);

  const vc = computeVoyage(records, voyage);
  const hours = (ms: number): Cell => ms === NO_TIME ? text('') : num(Math.round(ms / 36000) / 100);
  const hm = (ms: number): Cell => ms === NO_TIME ? text('') : text(fmtHM(ms));

  spec.rows.push([text('航行时间(小时)'), hours(vc.sailMs)]);
  spec.rows.push([text('航行时间(hh:mm)'), hm(vc.sailMs)]);
  spec.rows.push([text('营运时间(小时)'), hours(vc.opMs)]);
  spec.rows.push([text('营运时间(hh:mm)'), hm(vc.opMs)]);
  spec.rows.push([text('上一港在港时间(小时)'), hours(vc.portMs)]);
  spec.rows.push([text('燃油实际消耗(吨)'), vc.fuelReady ? num(Math.round(vc.fuel * 1000) / 1000) : text('')]);

  for (let i: number = 0; i < STATUS_LIST.length; i++) {
    const meta = STATUS_LIST[i];
    spec.rows.push([text(`${meta.name}合计(小时)`),
      vc.ok ? num(Math.round(vc.sums.get(meta.key) / 36000) / 100) : text('')]);
  }
  return spec;
}

/** 时间汇总 */
function summarySheet(records: ShipRecord[]): SheetSpec {
  const spec = new SheetSpec();
  spec.name = '时间汇总';
  spec.widths = [10, 12, 12, 22];
  spec.rows.push([text('状态'), text('时长(小时)'), text('时长(hh:mm)'), text('天-时-分-秒')]);

  const totals = computeSummary(records);
  for (let i: number = 0; i < STATUS_LIST.length; i++) {
    const meta = STATUS_LIST[i];
    const ms: number = totals.get(meta.key);
    const d = fmtDuration(ms);
    spec.rows.push([text(meta.name), num(Math.round(d.totalHours * 100) / 100), text(fmtHM(ms)), text(d.text)]);
  }
  const all: number = totals.total();
  const gd = fmtDuration(all);
  spec.rows.push([text('合计'), num(Math.round(gd.totalHours * 100) / 100), text(fmtHM(all)), text(gd.text)]);
  return spec;
}

/** 油耗参数 */
function rateSheet(rates: FuelRates): SheetSpec {
  const spec = new SheetSpec();
  spec.name = '油耗参数';
  spec.widths = [10, 20];
  spec.rows.push([text('状态'), text('燃油消耗率(吨/小时)')]);
  for (let i: number = 0; i < STATUS_LIST.length; i++) {
    spec.rows.push([text(STATUS_LIST[i].name), num(rates.get(STATUS_LIST[i].key))]);
  }
  return spec;
}

export function buildStatsWorkbook(records: ShipRecord[], rates: FuelRates,
  voyage: VoyageInfo): SheetSpec[] {
  const names = statusName(records);
  return [
    detailSheet(records, names),
    voyageSheet(records, voyage),
    summarySheet(records),
    rateSheet(rates)
  ];
}

/** 空白模板：表头 + 一行示例 */
export function buildTemplateWorkbook(): SheetSpec[] {
  const detail = new SheetSpec();
  detail.name = '时间区间明细';
  detail.widths = [6, 21, 21, 11, 9, 22];
  detail.rows.push([text('序号'), text('开始时间'), text('结束时间'),
    text('时长(小时)'), text('状态'), text('备注')]);
  detail.rows.push([Cell.ofNum(1), text('2026-11-19 08:00:00'), text('2026-11-19 12:00:00'),
    Cell.ofNum(4), text('航行'), text('上海→宁波（示例行，可删除）')]);
  detail.rows.push([Cell.ofNum(2), text('2026-11-19 12:00:00'), text('2026-11-19 18:00:00'),
    Cell.ofNum(6), text('锚泊'), text('等泊（示例行，可删除）')]);

  const voyage = new SheetSpec();
  voyage.name = '航次统计';
  voyage.widths = [36, 24];
  voyage.rows.push([text('项目'), text('内容')]);
  voyage.rows.push([text('航次名称'), text('')]);
  voyage.rows.push([text('上次抵港时间'), text('')]);
  voyage.rows.push([text('上次离港时间'), text('')]);
  voyage.rows.push([text('本次抵港时间'), text('')]);
  voyage.rows.push([text('上次抵港存油(吨)'), text('')]);
  voyage.rows.push([text('上次离港存油(吨)'), text('')]);
  voyage.rows.push([text('本次抵港存油(吨)'), text('')]);
  voyage.rows.push([text('燃油添加量(吨)'), text('')]);
  voyage.rows.push([text('燃油驳出量(吨)'), text('')]);

  const summary = new SheetSpec();
  summary.name = '时间汇总';
  summary.widths = [10, 12, 12, 22];
  summary.rows.push([text('状态'), text('时长(小时)'), text('时长(hh:mm)'), text('天-时-分-秒')]);
  for (let i: number = 0; i < STATUS_LIST.length; i++) {
    summary.rows.push([text(STATUS_LIST[i].name), text(''), text(''), text('')]);
  }
  summary.rows.push([text('合计'), text(''), text(''), text('')]);

  const rate = new SheetSpec();
  rate.name = '油耗参数';
  rate.widths = [10, 20];
  rate.rows.push([text('状态'), text('燃油消耗率(吨/小时)')]);
  for (let i: number = 0; i < STATUS_LIST.length; i++) {
    rate.rows.push([text(STATUS_LIST[i].name), text('')]);
  }

  return [detail, voyage, summary, rate];
}

export function statsFileName(): string {
  const d = new Date();
  const p = (n: number): string => n < 10 ? '0' + n : '' + n;
  return `船舶能耗统计-${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-` +
    `${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}.xlsx`;
}
