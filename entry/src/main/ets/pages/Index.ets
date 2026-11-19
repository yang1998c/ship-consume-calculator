/**
 * 船舶能耗计算器 —— 主界面
 * 五个页签：录入 / 航次 / 汇总 / 正午 / 明细
 */
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { promptAction, window } from '@kit.ArkUI';
import { DateTimeDialog } from '../components/DateTimeDialog';
import { AboutDialog } from '../components/AboutDialog';
import { PolicyViewDialog, PrivacyGateDialog } from '../components/PrivacyDialog';
import { LicenseDialog } from '../components/LicenseDialog';
import { HelpDialog } from '../components/HelpDialog';
import { DateTimeField, OffsetSelect, OilInput, ResultChip } from '../components/Fields';
import {
  computeFuel, computeNoon, computeSummary, computeVoyage, floorToMinute, fmtClockAdj, fmtDuration, fmtHM, fmtOffset,
  formatInZone, formatInZoneShort, formatWall, FuelResult, localOffsetMin, noonOffAt, offsetLabel,
  recordEndOff, recordStartOff, TZ_OFFSETS, wallToMs
} from '../model/Calc';
import {
  FuelRates, NoonResult, NoonSegment, NO_OFFSET, NO_TIME, ShipRecord, ShipStatus, STATUS_LIST, StatusMeta,
  StatusTotals, VoyageInfo, VoyageResult, emptyVoyage
} from '../model/Types';
import { Palette, Palettes } from '../model/Theme';
import { AppData, loadAppData, saveAppData } from '../model/Storage';
import { buildBackup, fileStamp, newId, parseBackup, pickFileUri, pickTextFile, saveBinaryFile, saveTextFile } from '../model/Store';
import { buildStatsWorkbook, buildTemplateWorkbook, statsFileName } from '../model/ExcelExport';
import { buildXlsx } from '../model/XlsxWriter';
import { ExcelImportResult, mapSheets, readXlsx } from '../model/XlsxReader';


const TARGET_START: number = 0;
const TARGET_END: number = 1;
const TARGET_V_LA: number = 2;
const TARGET_V_LD: number = 3;
const TARGET_V_TA: number = 4;
const TARGET_NOON_S: number = 5;
const TARGET_NOON_E: number = 6;

class TabDef {
  label: string = '';
  symbol: Resource = $r('sys.symbol.clock');
  index: number = 0;

  constructor(label: string, symbol: Resource, index: number) {
    this.label = label;
    this.symbol = symbol;
    this.index = index;
  }
}

const TAB_DEFS: TabDef[] = [
  new TabDef('录入', $r('sys.symbol.pencil_line'), 0),
  new TabDef('航次', $r('sys.symbol.compass'), 1),
  new TabDef('汇总', $r('sys.symbol.square_grid_2x2'), 2),
  new TabDef('正午', $r('sys.symbol.sun_max'), 3),
  new TabDef('明细', $r('sys.symbol.list_bullet'), 4)
];

@Entry
@Component
struct Index {
  // ---------- 数据 ----------
  @State records: ShipRecord[] = [];
  @State rates: FuelRates = new FuelRates();
  @State voyage: VoyageInfo = emptyVoyage();
  @State isDark: boolean = false;
  /** 全屏沉浸下的避让高度（vp） */
  @State topInset: number = 0;
  @State bottomInset: number = 0;
  @State curTab: number = 0;
  @State tabFade: number = 1;
  @State tabShift: number = 0;
  @State tabX: number = 0;

  // ---------- 录入表单 ----------
  @State startWall: number = 0;
  @State endWall: number = 0;
  @State startOff: number = 480;
  @State endOff: number = 480;
  @State formStatus: ShipStatus = ShipStatus.Sailing;
  @State remark: string = '';
  @State formMsg: string = '';
  @State formMsgOk: boolean = true;

  // ---------- 数值输入（字符串态，避免光标跳动） ----------
  @State rateTexts: string[] = ['0.80', '0.10', '0.20', '0.05', '0.10'];
  @State oilLastArrival: string = '';
  @State oilLastDeparture: string = '';
  @State oilThisArrival: string = '';
  @State oilAdded: string = '';
  @State oilTransferred: string = '';

  // ---------- 正午 ----------
  @State noonStart: number = NO_TIME;
  @State noonEnd: number = NO_TIME;
  @State noonRes: NoonResult = new NoonResult();

  // ---------- 对话框 ----------
  @State dlgWall: number = 0;
  @State dlgTarget: number = TARGET_START;
  dialogController: CustomDialogController = new CustomDialogController({
    builder: DateTimeDialog({
      wall: $dlgWall,
      isDark: $isDark,
      onConfirm: (v: number) => {
        this.applyPicked(v);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
    maskColor: '#66000000'
  });

  privacyController: CustomDialogController = new CustomDialogController({
    builder: PrivacyGateDialog({
      isDark: $isDark,
      onAgree: () => {
        this.privacyAgreed = true;
        this.persist();
        this.privacyController.close();
      },
      onReject: () => {
        const c = this.getUIContext().getHostContext() as common.UIAbilityContext;
        c.terminateSelf();
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: true,
    maskColor: '#66000000'
  });

  policyController: CustomDialogController = new CustomDialogController({
    builder: PolicyViewDialog({
      isDark: $isDark
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
    maskColor: '#66000000'
  });

  helpController: CustomDialogController = new CustomDialogController({
    builder: HelpDialog({
      isDark: $isDark
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
    maskColor: '#66000000'
  });

  licenseController: CustomDialogController = new CustomDialogController({
    builder: LicenseDialog({
      isDark: $isDark
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
    maskColor: '#66000000'
  });

  aboutController: CustomDialogController = new CustomDialogController({
    builder: AboutDialog({
      isDark: $isDark,
      onShowPolicy: () => {
        this.aboutController.close();
        this.policyController.open();
      },
      onShowLicense: () => {
        this.aboutController.close();
        this.licenseController.open();
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
    maskColor: '#66000000'
  });

  private privacyAgreed: boolean = false;
  private privacyPrompted: boolean = false;
  private ctx: common.UIAbilityContext | null = null;
  private tabsController: TabsController = new TabsController();

  // ---------- 生命周期 ----------

  aboutToAppear(): void {
    this.ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let data = new AppData();
    try {
      data = loadAppData(this.ctx);
    } catch (e) {
      data = new AppData();
    }
    this.records = data.records;
    this.rates = data.rates;
    this.voyage = data.voyage;
    this.noonStart = data.noonStart;
    this.noonEnd = data.noonEnd;
    this.isDark = data.dark;
    this.privacyAgreed = data.privacyAgreed;

    this.rateTexts = [
      '' + this.rates.sailing, '' + this.rates.anchorage, '' + this.rates.drifting,
      '' + this.rates.berthing, '' + this.rates.buoy
    ];
    this.oilLastArrival = this.oilText(this.voyage.oilLastArrival);
    this.oilLastDeparture = this.oilText(this.voyage.oilLastDeparture);
    this.oilThisArrival = this.oilText(this.voyage.oilThisArrival);
    this.oilAdded = this.oilText(this.voyage.oilAdded);
    this.oilTransferred = this.oilText(this.voyage.oilTransferred);

    if (this.startWall === 0) {
      const n = new Date();
      const base = wallToMs(n.getFullYear(), n.getMonth() + 1, n.getDate(),
        n.getHours(), n.getMinutes(), 0);
      this.startWall = base;
      this.endWall = base + 3600000;
      const off = localOffsetMin(Date.now());
      this.startOff = off;
      this.endOff = off;
    }
    this.refreshNoon();
    this.setupImmersive();
  }

  /** 状态栏/导航条图标颜色跟随主题：浅色底用深色图标，深色底用浅色图标 */
  private applySystemBars(): void {
    if (this.ctx === null) {
      return;
    }
    window.getLastWindow(this.ctx).then((win: window.Window) => {
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: this.isDark ? '#FFFFFF' : '#000000',
        navigationBarColor: '#00000000',
        navigationBarContentColor: this.isDark ? '#FFFFFF' : '#000000'
      });
    }).catch(() => {
    });
  }

  /** 全屏沉浸：系统栏透明、内容延伸到状态栏与手势条之下 */
  /** 切换页签：两段式水平推移——旧页推出，新页从另一侧推入 */
  private switchTab(index: number): void {
    if (index === this.curTab) {
      return;
    }
    const dir: number = index > this.curTab ? 1 : -1;
    const target: number = index;

    // 第一段：当前页向切换方向的反侧推出并淡出
    animateTo({
      duration: 130,
      curve: Curve.FastOutSlowIn,
      onFinish: () => {
        // 换页，新页面先落在来向一侧
        this.curTab = target;
        this.tabsController.changeIndex(target);
        this.tabX = dir * 90;
        this.tabFade = 0.15;
        // 第二段：新页面滑回原位并淡入
        animateTo({ duration: 240, curve: Curve.FastOutSlowIn }, () => {
          this.tabX = 0;
          this.tabFade = 1;
        });
      }
    }, () => {
      this.tabX = -dir * 70;
      this.tabFade = 0.15;
    });
  }

  /** 头部浮层高度（含状态栏安全区），内容据此留出滚动余量 */
  private headerH(): number {
    return this.topInset + 68;
  }

  private async setupImmersive(): Promise<void> {
    if (this.ctx === null) {
      return;
    }
    try {
      const win = await window.getLastWindow(this.ctx);
      await win.setWindowLayoutFullScreen(true);
      await win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: this.isDark ? '#FFFFFF' : '#000000',
        navigationBarColor: '#00000000',
        navigationBarContentColor: this.isDark ? '#FFFFFF' : '#000000'
      });
      const topArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const bottomArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const uiCtx = this.getUIContext();
      this.topInset = uiCtx.px2vp(topArea.topRect.height);
      this.bottomInset = uiCtx.px2vp(bottomArea.bottomRect.height);
    } catch (e) {
      this.topInset = 0;
      this.bottomInset = 0;
    }
  }

  onPageShow(): void {
    // 首帧之后再弹，避免窗口未就绪导致异常
    if (!this.privacyAgreed && !this.privacyPrompted) {
      this.privacyPrompted = true;
      setTimeout(() => {
        this.privacyController.open();
      }, 350);
    }
  }

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  private oilText(v: number): string {
    return v >= 0 ? '' + v : '';
  }

  private persist(): void {
    if (this.ctx === null) {
      return;
    }
    const data = new AppData();
    data.records = this.records;
    data.rates = this.rates;
    data.voyage = this.voyage;
    data.noonStart = this.noonStart;
    data.noonEnd = this.noonEnd;
    data.dark = this.isDark;
    data.privacyAgreed = this.privacyAgreed;
    try {
      saveAppData(this.ctx, data);
    } catch (e) {
      // 存储失败不阻断交互
    }
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2200 });
  }

  // ---------- 选择器 ----------

  /** 当前时刻的船钟墙钟毫秒（本地字段按 UTC 锚定） */
  private nowWall(): number {
    const n = new Date();
    return wallToMs(n.getFullYear(), n.getMonth() + 1, n.getDate(),
      n.getHours(), n.getMinutes(), n.getSeconds());
  }

  private openPicker(target: number, current: number): void {
    this.dlgTarget = target;
    this.dlgWall = current === NO_TIME ? this.nowWall() : current;
    this.dialogController.open();
  }

  private applyPicked(v: number): void {
    if (this.dlgTarget === TARGET_START) {
      this.startWall = v;
    } else if (this.dlgTarget === TARGET_END) {
      this.endWall = v;
    } else if (this.dlgTarget === TARGET_NOON_S) {
      this.noonStart = v;
      this.refreshNoon();
      this.persist();
    } else if (this.dlgTarget === TARGET_NOON_E) {
      this.noonEnd = v;
      this.refreshNoon();
      this.persist();
    } else {
      this.setVoyageTime(v, this.dlgTarget);
    }
  }

  private setVoyageTime(wall: number, target: number): void {
    const v: VoyageInfo = {
      name: this.voyage.name,
      lastArrival: this.voyage.lastArrival,
      lastDeparture: this.voyage.lastDeparture,
      thisArrival: this.voyage.thisArrival,
      oilLastArrival: this.voyage.oilLastArrival,
      oilLastDeparture: this.voyage.oilLastDeparture,
      oilThisArrival: this.voyage.oilThisArrival,
      oilAdded: this.voyage.oilAdded,
      oilTransferred: this.voyage.oilTransferred
    };
    if (target === TARGET_V_LA) {
      v.lastArrival = wall;
    } else if (target === TARGET_V_LD) {
      v.lastDeparture = wall;
    } else if (target === TARGET_V_TA) {
      v.thisArrival = wall;
    }
    this.voyage = v;
    this.persist();
  }

  private clearVoyageTime(target: number): void {
    this.setVoyageTime(NO_TIME, target);
  }

  // ---------- 录入 ----------

  private addRecord(): void {
    if (this.endWall <= this.startWall && this.startOff === this.endOff) {
      this.formMsg = '结束时间必须晚于开始时间';
      this.formMsgOk = false;
      return;
    }
    // 时间精度统一到分钟
    const start: number = floorToMinute(this.startWall - this.startOff * 60000);
    const end: number = floorToMinute(this.endWall - this.endOff * 60000);
    if (end <= start) {
      const hint: string = this.startOff !== this.endOff
        ? `（已按时区换算：${fmtOffset(this.startOff)} → ${fmtOffset(this.endOff)}，请检查墙钟时间与所选时区）`
        : '';
      this.formMsg = '结束时间必须晚于开始时间' + hint;
      this.formMsgOk = false;
      return;
    }
    const rec: ShipRecord = {
      id: newId(),
      start: start,
      end: end,
      status: this.formStatus,
      remark: this.remark.trim(),
      so: this.startOff,
      eo: this.endOff
    };
    this.records = this.records.concat([rec]);
    let msg: string = `已添加：${this.statusName(this.formStatus)} ${fmtDuration(end - start).text}`;
    if (this.startOff !== this.endOff) {
      const wallMs: number = this.endWall - this.startWall;
      const deltaMin: number = this.endOff - this.startOff;
      msg += `（墙钟 ${fmtHM(wallMs)}，拨钟 ${fmtClockAdj(deltaMin)}）`;
    }
    this.formMsg = msg;
    this.formMsgOk = true;
    this.remark = '';
    // 连续录入：上一段结束自动成为下一段开始
    this.startWall = this.endWall;
    this.startOff = this.endOff;
    this.refreshNoon();
    this.persist();
  }

  private deleteRecord(id: string): void {
    const next: ShipRecord[] = [];
    for (let i: number = 0; i < this.records.length; i++) {
      if (this.records[i].id !== id) {
        next.push(this.records[i]);
      }
    }
    this.records = next;
    this.refreshNoon();
    this.persist();
  }

  private clearRecords(): void {
    if (this.records.length === 0) {
      return;
    }
    AlertDialog.show({
      title: '清空时间区间',
      message: `确定要清空全部 ${this.records.length} 条时间区间吗？此操作不可恢复。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确定清空',
        fontColor: this.palette().danger,
        action: () => {
          this.records = [];
          this.refreshNoon();
          this.persist();
          this.toast('已清空全部时间区间');
        }
      }
    });
  }

  private resetAll(): void {
    let rateText: string = '';
    for (let i: number = 0; i < STATUS_LIST.length; i++) {
      if (rateText.length > 0) {
        rateText += ' / ';
      }
      rateText += STATUS_LIST[i].name + this.rates.get(STATUS_LIST[i].key).toFixed(2);
    }
    AlertDialog.show({
      title: '一键重置',
      message: '此操作不可恢复：清空全部时间区间、航次与存油数据、正午查询时间，' +
        `油耗率恢复缺省（${rateText} 吨/小时）。建议先保存备份。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确定重置',
        fontColor: this.palette().danger,
        action: () => {
          this.records = [];
          this.rates = new FuelRates();
          this.rateTexts = ['0.8', '0.1', '0.2', '0.05', '0.1'];
          this.voyage = emptyVoyage();
          this.oilLastArrival = '';
          this.oilLastDeparture = '';
          this.oilThisArrival = '';
          this.oilAdded = '';
          this.oilTransferred = '';
          this.noonStart = NO_TIME;
          this.noonEnd = NO_TIME;
          const n = new Date();
          const base = wallToMs(n.getFullYear(), n.getMonth() + 1, n.getDate(),
            n.getHours(), n.getMinutes(), 0);
          this.startWall = base;
          this.endWall = base + 3600000;
          this.startOff = localOffsetMin(Date.now());
          this.endOff = this.startOff;
          this.formStatus = ShipStatus.Sailing;
          this.remark = '';
          this.formMsg = '';
          this.refreshNoon();
          this.persist();
          this.toast('已重置为缺省状态');
        }
      }
    });
  }

  // ---------- 正午 ----------

  private refreshNoon(): void {
    this.noonRes = computeNoon(this.noonStart, this.noonEnd, this.records);
  }

  private fillNoonFromRecords(): void {
    if (this.records.length === 0) {
      this.toast('暂无时间区间，请先录入记录');
      return;
    }
    let mn: number = Infinity;
    let mx: number = -Infinity;
    for (let i: number = 0; i < this.records.length; i++) {
      const r = this.records[i];
      if (r.start < mn) {
        mn = r.start;
      }
      if (r.end > mx) {
        mx = r.end;
      }
    }
    this.noonStart = mn + noonOffAt(mn, this.records) * 60000;
    this.noonEnd = mx + noonOffAt(mx, this.records) * 60000;
    this.refreshNoon();
    this.persist();
  }

  // ---------- 数据操作 ----------

  private async doBackup(): Promise<void> {
    if (this.ctx === null) {
      return;
    }
    try {
      const content: string = buildBackup(this.records, this.rates, this.voyage);
      const uri: string = await saveTextFile(this.ctx, `船舶能耗备份-${fileStamp()}.json`, content);
      if (uri.length > 0) {
        this.toast(`备份文件已保存（共 ${this.records.length} 条时间区间）`);
      }
    } catch (e) {
      this.toast('保存备份失败');
    }
  }

  private async doRestore(): Promise<void> {
    if (this.ctx === null) {
      return;
    }
    try {
      const text: string = await pickTextFile(this.ctx, '.json');
      if (text.length === 0) {
        return;
      }
      const res = parseBackup(text);
      if (!res.ok) {
        this.toast(res.message);
        return;
      }
      AlertDialog.show({
        title: '恢复备份',
        message: `恢复备份将替换当前全部 ${this.records.length} 条时间区间和航次信息，确定继续？`,
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '确定恢复',
          action: () => {
            this.records = res.records;
            this.rates = res.rates;
            this.voyage = res.voyage;
            this.rateTexts = [
              '' + res.rates.sailing, '' + res.rates.anchorage, '' + res.rates.drifting,
              '' + res.rates.berthing, '' + res.rates.buoy
            ];
            this.oilLastArrival = this.oilText(res.voyage.oilLastArrival);
            this.oilLastDeparture = this.oilText(res.voyage.oilLastDeparture);
            this.oilThisArrival = this.oilText(res.voyage.oilThisArrival);
            this.oilAdded = this.oilText(res.voyage.oilAdded);
            this.oilTransferred = this.oilText(res.voyage.oilTransferred);
            this.refreshNoon();
            this.persist();
            this.toast(res.message);
          }
        }
      });
    } catch (e) {
      const err = e as BusinessError;
      this.toast(`读取备份文件失败：${err.message ?? err.code ?? '未知错误'}`);
    }
  }

  private async doExportExcel(): Promise<void> {
    if (this.ctx === null) {
      return;
    }
    try {
      const data: Uint8Array = buildXlsx(buildStatsWorkbook(this.records, this.rates, this.voyage));
      const uri: string = await saveBinaryFile(this.ctx, statsFileName(), data);
      if (uri.length > 0) {
        this.toast(`已导出 Excel：${this.records.length} 条时间区间`);
      }
    } catch (e) {
      const err = e as BusinessError;
      this.toast(`导出失败：${err.message ?? '未知错误'}`);
    }
  }

  private async doDownloadTemplate(): Promise<void> {
    if (this.ctx === null) {
      return;
    }
    try {
      const data: Uint8Array = buildXlsx(buildTemplateWorkbook());
      const uri: string = await saveBinaryFile(this.ctx, '船舶能耗统计模板.xlsx', data);
      if (uri.length > 0) {
        this.toast('模板已保存，填写后用「导入 Excel」导入');
      }
    } catch (e) {
      this.toast('保存模板失败');
    }
  }

  private async doImportExcel(): Promise<void> {
    if (this.ctx === null) {
      return;
    }
    try {
      const uri: string = await pickFileUri(this.ctx, '.xlsx');
      if (uri.length === 0) {
        return;
      }
      const sheets = await readXlsx(this.ctx, uri);
      const res: ExcelImportResult = mapSheets(sheets);
      if (res.records.length === 0) {
        const detail: string = res.errors.length > 0 ? `：${res.errors.slice(0, 2).join('；')}` : '';
        this.toast(`没有可导入的时间区间${detail}`);
        return;
      }
      const extra: string[] = [];
      if (res.voyageTimes[0] !== NO_TIME || res.oils[0] >= 0) {
        extra.push('航次信息');
      }
      if (res.rates.size > 0) {
        extra.push('油耗参数');
      }
      const extraText: string = extra.length > 0 ? `，以及${extra.join('、')}` : '';
      const errText: string = res.errors.length > 0 ? `\n另有 ${res.errors.length} 行无法解析，已跳过。` : '';
      AlertDialog.show({
        title: '导入 Excel',
        message: `将导入 ${res.records.length} 条时间区间${extraText}，并替换当前 ${this.records.length} 条记录。${errText}`,
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '替换导入',
          action: () => {
            this.applyExcelImport(res);
          }
        }
      });
    } catch (e) {
      const err = e as BusinessError;
      this.toast(`读取 Excel 失败：${err.message ?? '未知错误'}`);
    }
  }

  private applyExcelImport(res: ExcelImportResult): void {
    this.records = res.records;

    const v: VoyageInfo = {
      name: res.voyageName,
      lastArrival: res.voyageTimes[0],
      lastDeparture: res.voyageTimes[1],
      thisArrival: res.voyageTimes[2],
      oilLastArrival: res.oils[0],
      oilLastDeparture: res.oils[1],
      oilThisArrival: res.oils[2],
      oilAdded: res.oils[3],
      oilTransferred: res.oils[4]
    };
    this.voyage = v;
    this.oilLastArrival = this.oilText(v.oilLastArrival);
    this.oilLastDeparture = this.oilText(v.oilLastDeparture);
    this.oilThisArrival = this.oilText(v.oilThisArrival);
    this.oilAdded = this.oilText(v.oilAdded);
    this.oilTransferred = this.oilText(v.oilTransferred);

    if (res.rates.size > 0) {
      const r: FuelRates = this.rates.clone();
      res.rates.forEach((value: number, key: string) => {
        r.set(key as ShipStatus, value);
      });
      this.rates = r;
      this.rateTexts = [
        '' + r.sailing, '' + r.anchorage, '' + r.drifting, '' + r.berthing, '' + r.buoy
      ];
    }

    this.refreshNoon();
    this.persist();
    this.toast(`已导入 ${res.records.length} 条时间区间`);
  }

  // ---------- 计算入口 ----------

  private statusName(s: ShipStatus): string {
    for (let i: number = 0; i < STATUS_LIST.length; i++) {
      if (STATUS_LIST[i].key === s) {
        return STATUS_LIST[i].name;
      }
    }
    return '航行';
  }

  private totals(): StatusTotals {
    return computeSummary(this.records);
  }

  private fuelResult(): FuelResult {
    return computeFuel(this.totals(), this.rates);
  }

  private voyageResult(): VoyageResult {
    return computeVoyage(this.records, this.voyage);
  }

  private onRateChange(index: number, text: string): void {
    const next: string[] = this.rateTexts.slice();
    next[index] = text;
    this.rateTexts = next;
    const n: number = text.trim().length === 0 ? 0 : Number(text);
    const r: FuelRates = this.rates.clone();
    r.set(STATUS_LIST[index].key, Number.isNaN(n) ? 0 : n);
    this.rates = r;
    this.persist();
  }

  private onOilChange(field: number, text: string): void {
    if (field === 0) {
      this.oilLastArrival = text;
    } else if (field === 1) {
      this.oilLastDeparture = text;
    } else if (field === 2) {
      this.oilThisArrival = text;
    } else if (field === 3) {
      this.oilAdded = text;
    } else {
      this.oilTransferred = text;
    }
    const v: VoyageInfo = {
      name: this.voyage.name,
      lastArrival: this.voyage.lastArrival,
      lastDeparture: this.voyage.lastDeparture,
      thisArrival: this.voyage.thisArrival,
      oilLastArrival: this.parseNum(this.oilLastArrival),
      oilLastDeparture: this.parseNum(this.oilLastDeparture),
      oilThisArrival: this.parseNum(this.oilThisArrival),
      oilAdded: this.parseNum(this.oilAdded),
      oilTransferred: this.parseNum(this.oilTransferred)
    };
    this.voyage = v;
    this.persist();
  }

  private parseNum(text: string): number {
    const t: string = text.trim();
    if (t.length === 0) {
      return -1;
    }
    const n: number = Number(t);
    return Number.isNaN(n) ? -1 : n;
  }

  // ---------- 通用 UI 片段 ----------

  @Builder
  sectionHeader(no: string, title: string, kicker: string) {
    Row({ space: 8 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.palette().heading)
        .layoutWeight(1)
      Text(kicker)
        .fontSize(11)
        .fontColor(this.palette().muted)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  fieldLabel(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(this.palette().muted)
      .margin({ bottom: 5 })
  }

  @Builder
  statusChip(meta: StatusMeta) {
    Text(meta.name)
      .fontSize(13)
      .fontWeight(this.formStatus === meta.key ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.formStatus === meta.key ? this.palette().onAccent : this.palette().statusInk(meta.key))
      .backgroundColor(this.formStatus === meta.key
        ? this.palette().statusColor(meta.key)
        : this.palette().statusSoft(meta.key))
      .borderRadius(16)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.formStatus = meta.key;
      })
  }

  @Builder
  primaryButton(label: string, action: () => void) {
    Button(label)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.palette().onAccent)
      .backgroundColor(this.palette().accent)
      .borderRadius(22)
      .height(44)
      .width('100%')
      .onClick(action)
  }

  @Builder
  outlineButton(label: string, action: () => void) {
    Button(label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.palette().accent)
      .backgroundColor(this.isDark ? '#33317AF7' : '#1A0A59F7')
      .borderRadius(20)
      .height(40)
      .layoutWeight(1)
      .onClick(action)
  }

  @Builder
  ghostButton(label: string, action: () => void) {
    Button(label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.palette().danger)
      .backgroundColor(this.isDark ? '#33FF6B57' : '#1AE84026')
      .borderRadius(20)
      .height(40)
      .layoutWeight(1)
      .onClick(action)
  }

  // ---------- 页签 1：录入 ----------

  @Builder
  entryTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.sectionHeader('01', '添加时间区间', 'Log Entry')

          Column({ space: 12 }) {
            Column() {
              this.fieldLabel('开始时间（当地船钟）')
              DateTimeField({ wall: this.startWall, isDark: this.isDark, weighted: false, onTap: () => { this.openPicker(TARGET_START, this.startWall); } })
              Row() {
                Text('船钟时区')
                  .fontSize(11)
                  .fontColor(this.palette().muted)
                  .layoutWeight(1)
                OffsetSelect({ off: this.startOff, isDark: this.isDark, onPick: (i: number) => { this.startOff = TZ_OFFSETS[i]; } })
              }
              .width('100%')
              .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column() {
              this.fieldLabel('结束时间（当地船钟）')
              DateTimeField({ wall: this.endWall, isDark: this.isDark, weighted: false, onTap: () => { this.openPicker(TARGET_END, this.endWall); } })
              Row() {
                Text('船钟时区')
                  .fontSize(11)
                  .fontColor(this.palette().muted)
                  .layoutWeight(1)
                OffsetSelect({ off: this.endOff, isDark: this.isDark, onPick: (i: number) => { this.endOff = TZ_OFFSETS[i]; } })
              }
              .width('100%')
              .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column() {
              this.fieldLabel('船舶状态')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(STATUS_LIST, (meta: StatusMeta) => {
                  this.statusChip(meta)
                }, (meta: StatusMeta) => meta.key)
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column() {
              this.fieldLabel('备注（可选）')
              TextInput({ text: this.remark, placeholder: '如：上海→宁波' })
                .fontSize(15)
                .fontColor(this.palette().heading)
                .placeholderColor(this.palette().muted)
                .backgroundColor(this.palette().inputBg)
                .borderRadius(10)
                .border({ width: 1, color: this.palette().line })
                .height(44)
                .onChange((v: string) => {
                  this.remark = v;
                })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            this.primaryButton('＋ 添加区间', () => {
              this.addRecord();
            })

            if (this.formMsg.length > 0) {
              Text(this.formMsg)
                .fontSize(12)
                .fontColor(this.formMsgOk ? this.palette().ok : this.palette().danger)
                .width('100%')
            }
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)

        Column() {
          this.sectionHeader('02', '最近录入', 'Recent')
          if (this.records.length === 0) {
            Text('暂无时间区间，录入第一段记录后统计与油耗将自动更新')
              .fontSize(12)
              .fontColor(this.palette().muted)
              .width('100%')
          } else {
            ForEach(this.recentRecords(), (rec: ShipRecord) => {
              this.recordRow(rec, -1)
            }, (rec: ShipRecord) => rec.id)
          }
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.headerH() + 12, bottom: 110 })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
  }

  private recentRecords(): ShipRecord[] {
    const sorted: ShipRecord[] = this.records.slice();
    sorted.sort((a: ShipRecord, b: ShipRecord) => b.start - a.start);
    return sorted.slice(0, 3);
  }

  // ---------- 页签 2：航次 ----------

  @Builder
  voyageTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.sectionHeader('01', '航次时间节点', 'Voyage')
          Column({ space: 12 }) {
            Column() {
              this.fieldLabel('上次抵港时间')
              Row({ space: 6 }) {
                DateTimeField({ wall: this.voyage.lastArrival, isDark: this.isDark, weighted: true, onTap: () => { this.openPicker(TARGET_V_LA, this.voyage.lastArrival); } })
                Text('✕')
                  .fontSize(12)
                  .fontColor(this.palette().muted)
                  .padding(6)
                  .onClick(() => {
                    this.clearVoyageTime(TARGET_V_LA);
                  })
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column() {
              this.fieldLabel('上次离港时间')
              Row({ space: 6 }) {
                DateTimeField({ wall: this.voyage.lastDeparture, isDark: this.isDark, weighted: true, onTap: () => { this.openPicker(TARGET_V_LD, this.voyage.lastDeparture); } })
                Text('✕')
                  .fontSize(12)
                  .fontColor(this.palette().muted)
                  .padding(6)
                  .onClick(() => {
                    this.clearVoyageTime(TARGET_V_LD);
                  })
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column() {
              this.fieldLabel('本次抵港时间')
              Row({ space: 6 }) {
                DateTimeField({ wall: this.voyage.thisArrival, isDark: this.isDark, weighted: true, onTap: () => { this.openPicker(TARGET_V_TA, this.voyage.thisArrival); } })
                Text('✕')
                  .fontSize(12)
                  .fontColor(this.palette().muted)
                  .padding(6)
                  .onClick(() => {
                    this.clearVoyageTime(TARGET_V_TA);
                  })
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)

        Column() {
          this.sectionHeader('02', '存油数据（吨）', 'Fuel Stock')
          Column({ space: 10 }) {
            OilInput({ label: '上次抵港存油', value: this.oilLastArrival, isDark: this.isDark, onInput: (v: string) => { this.onOilChange(0, v); } })
            OilInput({ label: '上次离港存油', value: this.oilLastDeparture, isDark: this.isDark, onInput: (v: string) => { this.onOilChange(1, v); } })
            OilInput({ label: '本次抵港存油', value: this.oilThisArrival, isDark: this.isDark, onInput: (v: string) => { this.onOilChange(2, v); } })
            OilInput({ label: '燃油添加量', value: this.oilAdded, isDark: this.isDark, onInput: (v: string) => { this.onOilChange(3, v); } })
            OilInput({ label: '燃油驳出量', value: this.oilTransferred, isDark: this.isDark, onInput: (v: string) => { this.onOilChange(4, v); } })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)

        Column() {
          this.sectionHeader('03', '核算结果', 'Result')
          this.voyageResultView()
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.headerH() + 12, bottom: 110 })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
  }

  @Builder
  voyageResultView() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        ResultChip({ label: '航行时间', ms: this.voyageResult().sailMs, isDark: this.isDark })
        ResultChip({ label: '营运时间', ms: this.voyageResult().opMs, isDark: this.isDark })
        ResultChip({ label: '上一港在港', ms: this.voyageResult().portMs, isDark: this.isDark })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row() {
        Column({ space: 2 }) {
          Text('燃油实际消耗')
            .fontSize(11)
            .fontColor(this.palette().fuelText)
          Row({ space: 3 }) {
            Text(this.voyageResult().fuelReady ? this.voyageResult().fuel.toFixed(3) : '—')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.palette().fuelText)
            Text('吨')
              .fontSize(10)
              .fontColor(this.palette().fuelText)
              .margin({ bottom: 4 })
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 2 }) {
          Text('窗口内已覆盖')
            .fontSize(11)
            .fontColor(this.palette().muted)
          Text(`${this.voyageResult().matched} 条 · ${fmtHM(this.voyageResult().coveredMs)}`)
            .fontSize(12)
            .fontColor(this.palette().text)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding(10)
      .backgroundColor(this.palette().fuelBg)
      .borderRadius(10)
      .border({ width: 1, color: this.palette().fuelBorder })

      if (this.voyageResult().ok) {
        Column({ space: 5 }) {
          ForEach(STATUS_LIST, (meta: StatusMeta) => {
            Row() {
              Text(meta.name)
                .fontSize(12)
                .fontColor(this.palette().statusInk(meta.key))
                .layoutWeight(1)
              Text(`${fmtHM(this.voyageResult().sums.get(meta.key))} · ${(this.voyageResult().sums.get(meta.key) / 3600000).toFixed(2)} h`)
                .fontSize(12)
                .fontColor(this.palette().text)
            }
            .width('100%')
          }, (meta: StatusMeta) => meta.key)
        }
        .width('100%')
        .padding(10)
        .backgroundColor(this.palette().subtle)
        .borderRadius(10)
      }

      ForEach(this.voyageResult().warns, (w: string) => {
        Text('⚠ ' + w)
          .fontSize(11)
          .fontColor(this.palette().danger)
          .width('100%')
      }, (w: string) => w)
    }
    .width('100%')
  }

  // ---------- 页签 3：汇总 ----------

  @Builder
  summaryTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.sectionHeader('01', '时间汇总', 'Time Summary')
          Column({ space: 10 }) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(STATUS_LIST, (meta: StatusMeta) => {
                this.statCard(meta)
              }, (meta: StatusMeta) => meta.key)
            }
            .width('100%')

            Divider().color(this.palette().line)

            Row() {
              Text(`区间总数 ${this.records.length} 条`)
                .fontSize(12)
                .fontColor(this.palette().muted)
                .layoutWeight(1)
              Text(`全部合计 ${fmtDuration(this.totals().total()).totalHours.toFixed(2)} 小时`)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.palette().heading)
            }
            .width('100%')

            Text(`${fmtHM(this.totals().total())}（hh:mm） · ${fmtDuration(this.totals().total()).text}`)
              .fontSize(11)
              .fontColor(this.palette().muted)
              .width('100%')
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)

        Column() {
          this.sectionHeader('02', '能耗参数设置', 'Fuel Rate')
          Column({ space: 10 }) {
            ForEach(STATUS_LIST, (meta: StatusMeta) => {
              Row({ space: 10 }) {
                Text(meta.name + '油耗率')
                  .fontSize(13)
                  .fontColor(this.palette().statusInk(meta.key))
                  .layoutWeight(1)
                TextInput({ text: this.rateTexts[this.statusIndex(meta.key)], placeholder: '0.00' })
                  .type(InputType.NUMBER_DECIMAL)
                  .fontSize(15)
                  .fontColor(this.palette().fuelText)
                  .placeholderColor(this.palette().muted)
                  .backgroundColor(this.palette().fuelBg)
                  .borderRadius(9)
                  .border({ width: 1, color: this.palette().fuelBorder })
                  .height(40)
                  .width(100)
                  .textAlign(TextAlign.End)
                  .onChange((v: string) => {
                    this.onRateChange(this.statusIndex(meta.key), v);
                  })
                Text('吨/时')
                  .fontSize(10)
                  .fontColor(this.palette().muted)
              }
              .width('100%')
            }, (meta: StatusMeta) => meta.key)

            Column({ space: 4 }) {
              Row() {
                Text('预计总能耗')
                  .fontSize(13)
                  .fontColor(this.palette().fuelText)
                  .layoutWeight(1)
                Text(`${this.fuelResult().total.toFixed(3)} 吨`)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.palette().fuelText)
              }
              .width('100%')
              Text(this.fuelBreakdown())
                .fontSize(10)
                .fontColor(this.palette().fuelText)
                .width('100%')
            }
            .width('100%')
            .padding(10)
            .backgroundColor(this.palette().fuelBg)
            .borderRadius(10)
            .border({ width: 1, color: this.palette().fuelBorder })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.headerH() + 12, bottom: 110 })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
  }

  private statusIndex(key: ShipStatus): number {
    for (let i: number = 0; i < STATUS_LIST.length; i++) {
      if (STATUS_LIST[i].key === key) {
        return i;
      }
    }
    return 0;
  }

  private fuelBreakdown(): string {
    const rows: string[] = [];
    for (let i: number = 0; i < this.fuelResult().rows.length; i++) {
      const r = this.fuelResult().rows[i];
      rows.push(`${r.name} ${r.fuel.toFixed(3)} 吨`);
    }
    return rows.join('　|　');
  }

  @Builder
  statCard(meta: StatusMeta) {
    Column({ space: 3 }) {
      Row() {
        Text(meta.name)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().statusInk(meta.key))
          .layoutWeight(1)
        Text(fmtHM(this.totals().get(meta.key)))
          .fontSize(10)
          .fontColor(this.palette().muted)
      }
      .width('100%')

      Row({ space: 3 }) {
        Text(fmtDuration(this.totals().get(meta.key)).totalHours.toFixed(2))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().heading)
        Text('小时')
          .fontSize(10)
          .fontColor(this.palette().muted)
          .margin({ bottom: 4 })
      }
      .alignItems(VerticalAlign.Bottom)

      Text(fmtDuration(this.totals().get(meta.key)).text)
        .fontSize(10)
        .fontColor(this.palette().muted)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(4)
          .backgroundColor(this.palette().subtle)
          .borderRadius(2)
        Row()
          .width(this.barWidth(this.totals().get(meta.key), this.totals().total()))
          .height(4)
          .backgroundColor(this.palette().statusColor(meta.key))
          .borderRadius(2)
      }
      .width('100%')
      .height(4)
      .margin({ top: 3 })
    }
    .width('46%')
    .margin({ right: 6, bottom: 6 })
    .padding(10)
    .backgroundColor(this.palette().statusSoft(meta.key))
    .borderRadius(10)
    .alignItems(HorizontalAlign.Start)
  }

  private barWidth(ms: number, grand: number): string {
    if (grand <= 0) {
      return '0%';
    }
    const pct: number = ms / grand * 100;
    return pct.toFixed(1) + '%';
  }

  // ---------- 页签 4：正午 ----------

  @Builder
  noonTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.sectionHeader('01', '统计区间（船钟）', 'Noon Range')
          Column({ space: 12 }) {
            Column() {
              this.fieldLabel('统计起始时间')
              DateTimeField({ wall: this.noonStart, isDark: this.isDark, weighted: false, onTap: () => { this.openPicker(TARGET_NOON_S, this.noonStart); } })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column() {
              this.fieldLabel('统计结束时间')
              DateTimeField({ wall: this.noonEnd, isDark: this.isDark, weighted: false, onTap: () => { this.openPicker(TARGET_NOON_E, this.noonEnd); } })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Row({ space: 8 }) {
              this.outlineButton('按记录填充', () => {
                this.fillNoonFromRecords();
              })
              this.outlineButton('清空', () => {
                this.noonStart = NO_TIME;
                this.noonEnd = NO_TIME;
                this.refreshNoon();
                this.persist();
              })
            }
            .width('100%')

            Text('以船钟每天 12:00 为分割点自动切段，跨时区拨钟按记录的船钟偏移推算（拨钟日段长 23/25 小时）')
              .fontSize(10)
              .fontColor(this.palette().muted)
              .width('100%')
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)

        Column() {
          this.sectionHeader('02', '正午分段时长', 'Noon Breakdown')
          this.noonTableView()
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.headerH() + 12, bottom: 110 })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
  }

  @Builder
  noonTableView() {
    Column({ space: 8 }) {
      if (!this.noonRes.valid) {
        Text(this.noonRes.message)
          .fontSize(12)
          .fontColor(this.palette().muted)
          .width('100%')
      } else {
        Scroll() {
          Column() {
            Row() {
              this.noonTh('#', 32)
              this.noonTh('分段（船钟 12:00 切分）', 150)
              ForEach(STATUS_LIST, (meta: StatusMeta) => {
                this.noonTh(meta.name, 56)
              }, (meta: StatusMeta) => meta.key)
              this.noonTh('段内合计', 60)
              this.noonTh('未覆盖/重叠', 76)
            }
            .backgroundColor(this.palette().subtle)

            ForEach(this.noonRes.segments, (seg: NoonSegment, i: number) => {
              Row() {
                Text('' + (i + 1))
                  .fontSize(11)
                  .fontColor(this.palette().muted)
                  .width(32)
                  .textAlign(TextAlign.Center)
                Column({ space: 1 }) {
                  Text(`${formatInZoneShort(seg.startAbs, seg.startOff)} → ${formatInZoneShort(seg.endAbs, seg.endOff)}`)
                    .fontSize(10)
                    .fontColor(this.palette().heading)
                  Text(this.segLenText(seg))
                    .fontSize(9)
                    .fontColor(this.palette().muted)
                }
                .width(150)
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 4 })

                ForEach(STATUS_LIST, (meta: StatusMeta) => {
                  Text(seg.sums.get(meta.key) > 0 ? fmtHM(seg.sums.get(meta.key)) : '—')
                    .fontSize(11)
                    .fontColor(seg.sums.get(meta.key) > 0 ? this.palette().text : this.palette().muted)
                    .width(56)
                    .textAlign(TextAlign.Center)
                }, (meta: StatusMeta) => meta.key)

                Text(fmtHM(seg.coveredMs))
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.palette().heading)
                  .width(60)
                  .textAlign(TextAlign.Center)

                Text(this.gapText(seg.gapMs))
                  .fontSize(10)
                  .fontColor(seg.gapMs > 1000
                    ? this.palette().signal
                    : (seg.gapMs < -1000 ? this.palette().danger : this.palette().muted))
                  .width(76)
                  .textAlign(TextAlign.Center)
              }
              .height(38)
              .backgroundColor(i % 2 === 0 ? Color.Transparent : this.palette().subtle)
              .border({ width: { bottom: 1 }, color: this.palette().line })
            }, (seg: NoonSegment) => '' + seg.startAbs)

            Row() {
              Text('')
                .width(32)
              Text(`合计（${this.noonRes.segments.length} 段）`)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.palette().heading)
                .width(150)
              ForEach(STATUS_LIST, (meta: StatusMeta) => {
                Text(fmtHM(this.noonRes.grand.get(meta.key)))
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.palette().heading)
                  .width(56)
                  .textAlign(TextAlign.Center)
              }, (meta: StatusMeta) => meta.key)
              Text(fmtHM(this.noonRes.grandCovered))
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.palette().heading)
                .width(60)
                .textAlign(TextAlign.Center)
              Text(this.gapText(this.noonRes.rangeMs - this.noonRes.grandCovered))
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.palette().heading)
                .width(76)
                .textAlign(TextAlign.Center)
            }
            .height(42)
            .backgroundColor(this.palette().subtle)
          }
          .width(32 + 150 + 56 * 5 + 60 + 76)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .width('100%')
        .borderRadius(8)
        .border({ width: 1, color: this.palette().line })

        Text(this.noonNote())
          .fontSize(11)
          .fontColor(this.noonRes.rangeMs - this.noonRes.grandCovered > 1000
            ? this.palette().signal
            : this.palette().ok)
          .width('100%')
      }
    }
    .width('100%')
  }

  private segLenText(seg: NoonSegment): string {
    const clockAdj: number = seg.endOff - seg.startOff;
    let s: string = `段长 ${fmtHM(seg.endAbs - seg.startAbs)}（${((seg.endAbs - seg.startAbs) / 3600000).toFixed(1)}h）`;
    if (clockAdj !== 0) {
      s += ` · 拨钟 ${fmtClockAdj(clockAdj)}`;
    }
    return s;
  }

  private gapText(gap: number): string {
    if (Math.abs(gap) < 1000) {
      return '—';
    }
    return (gap > 0 ? '未覆盖 ' : '重叠 ') + fmtHM(Math.abs(gap));
  }

  private noonNote(): string {
    const gap: number = this.noonRes.rangeMs - this.noonRes.grandCovered;
    if (Math.abs(gap) < 1000 && !this.noonRes.overlap) {
      return `✓ 校验通过：各状态合计 = 区间总长 ${fmtHM(this.noonRes.rangeMs)}`;
    }
    if (gap > 0) {
      return `⚠ 有 ${fmtHM(gap)} 未被任何状态区间覆盖，请补录缺少的记录`;
    }
    return `⚠ 各状态合计比区间总长多 ${fmtHM(-gap)}，时间区间可能存在重叠`;
  }

  @Builder
  noonTh(label: string, w: number) {
    Text(label)
      .fontSize(10)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.palette().muted)
      .width(w)
      .height(32)
      .textAlign(TextAlign.Center)
  }

  // ---------- 页签 5：明细 ----------

  @Builder
  recordsTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column() {
          this.sectionHeader('01', '数据管理', 'Data')
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              this.outlineButton('保存备份', () => {
                this.doBackup();
              })
              this.outlineButton('恢复备份', () => {
                this.doRestore();
              })
            }
            .width('100%')

            Row({ space: 8 }) {
              this.outlineButton('导出 Excel', () => {
                this.doExportExcel();
              })
              this.outlineButton('导入 Excel', () => {
                this.doImportExcel();
              })
            }
            .width('100%')

            Row({ space: 8 }) {
              this.outlineButton('下载模板', () => {
                this.doDownloadTemplate();
              })
              this.ghostButton('清空区间', () => {
                this.clearRecords();
              })
            }
            .width('100%')

            Row({ space: 8 }) {
              this.ghostButton('一键重置', () => {
                this.resetAll();
              })
            }
            .width('100%')

            Column({ space: 3 }) {
              Text('数据自动保存在本机；备份为 .json；Excel 含 4 张报表，可导出、导入与下载模板')
                .fontSize(10)
                .fontColor(this.palette().muted)
                .width('100%')
              Row({ space: 4 }) {
                Text('ℹ')
                  .fontSize(10)
                  .fontColor(this.palette().accent)
                Text('Excel 最后一个工作表是「填写说明」，填写格式与注意事项请看那里')
                  .fontSize(10)
                  .fontColor(this.palette().accent)
                  .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }
            .width('100%')
            .padding(10)
            .backgroundColor(this.palette().subtle)
            .borderRadius(10)
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)

        Column() {
          this.sectionHeader('02', '时间区间明细', 'Records')
          if (this.sortedRecords().length === 0) {
            Column({ space: 4 }) {
              Text('暂无时间区间')
                .fontSize(14)
                .fontColor(this.palette().heading)
              Text('在「录入」页添加第一段记录，统计与油耗将自动更新')
                .fontSize(11)
                .fontColor(this.palette().muted)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ top: 20, bottom: 20 })
            .alignItems(HorizontalAlign.Center)
          } else {
            ForEach(this.sortedRecords(), (rec: ShipRecord, idx: number) => {
              this.recordRow(rec, idx)
            }, (rec: ShipRecord) => rec.id)
          }
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(this.palette().card)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.headerH() + 12, bottom: 110 })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
  }

  private sortedRecords(): ShipRecord[] {
    const sorted: ShipRecord[] = this.records.slice();
    sorted.sort((a: ShipRecord, b: ShipRecord) => a.start - b.start);
    return sorted;
  }

  @Builder
  recordRow(rec: ShipRecord, idx: number) {
    Column({ space: 5 }) {
      Row({ space: 6 }) {
        if (idx >= 0) {
          Text('' + (idx + 1))
            .fontSize(10)
            .fontColor(this.palette().muted)
            .width(18)
        }
        Text(this.statusName(rec.status))
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().statusInk(rec.status))
          .backgroundColor(this.palette().statusSoft(rec.status))
          .borderRadius(5)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        Text(fmtDuration(rec.end - rec.start).text)
          .fontSize(11)
          .fontColor(this.palette().heading)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('✕')
          .fontSize(13)
          .fontColor(this.palette().muted)
          .padding(4)
          .onClick(() => {
            this.deleteRecord(rec.id);
          })
      }
      .width('100%')

      Text(`${formatInZone(rec.start, recordStartOff(rec))}  ${fmtOffset(recordStartOff(rec))}`)
        .fontSize(10)
        .fontColor(this.palette().muted)
        .width('100%')
      Text(`${formatInZone(rec.end, recordEndOff(rec))}  ${fmtOffset(recordEndOff(rec))}`)
        .fontSize(10)
        .fontColor(this.palette().muted)
        .width('100%')

      if (rec.so !== NO_OFFSET && rec.eo !== NO_OFFSET && rec.so !== rec.eo) {
        Text(`墙钟 ${fmtHM((rec.end + rec.eo * 60000) - (rec.start + rec.so * 60000))}｜拨钟 ${fmtClockAdj(rec.eo - rec.so)}`)
          .fontSize(9)
          .fontColor(this.palette().signal)
          .width('100%')
      }

      if (rec.remark.length > 0) {
        Text(rec.remark)
          .fontSize(11)
          .fontColor(this.palette().text)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .border({ width: { bottom: 1 }, color: this.palette().line })
  }

  // ---------- 页头 / 页签栏 ----------

  /** 沉浸光感底色：海图纸/暗舱渐变 + 两处柔光晕，给磨砂层提供折射内容 */
  @Builder
  backdrop() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [[this.palette().paper, 0.0], [this.palette().paperAlt, 1.0]]
        })
      Column()
        .width(380)
        .height(380)
        .borderRadius(190)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 190,
          colors: [[this.palette().glowA, 0.0], ['#00000000', 1.0]]
        })
        .position({ x: -120, y: -110 })
      Column()
        .width(320)
        .height(320)
        .borderRadius(160)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 160,
          colors: [[this.palette().glowB, 0.0], ['#00000000', 1.0]]
        })
        .position({ x: 210, y: 470 })
    }
    .width('100%')
    .height('100%')
  }

  /** 悬浮胶囊页签栏（系统应用常见形态） */
  @Builder
  pillBar() {
    Row() {
      ForEach(TAB_DEFS, (t: TabDef) => {
        Column({ space: 3 }) {
          SymbolGlyph(t.symbol)
            .fontSize(22)
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
            .fontColor([this.curTab === t.index ? this.palette().accent : this.palette().muted])
          Text(t.label)
            .fontSize(10)
            .fontWeight(this.curTab === t.index ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.curTab === t.index ? this.palette().accent : this.palette().muted)
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.switchTab(t.index);
        })
      }, (t: TabDef) => t.label)
    }
    .width('88%')
    .height(62)
    .backgroundColor(this.palette().glassBar)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK,
      { colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT })
    .border({ width: 0.5, color: this.palette().line })
    .borderRadius(31)
    .shadow({ radius: 20, color: this.palette().cardShadow, offsetY: 6 })
    .margin({ bottom: this.bottomInset + 10 })
  }

  @Builder
  appHeader() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text('船舶能耗计算器')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().heading)
        Text('SHIP ENERGY LOG')
          .fontSize(10)
          .letterSpacing(1.2)
          .fontColor(this.palette().muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row() {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(20)
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .fontColor([this.palette().text])
      }
      .justifyContent(FlexAlign.Center)
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.palette().subtle)
      .onClick(() => {
        this.helpController.open();
      })

      Row() {
        SymbolGlyph($r('sys.symbol.envelope'))
          .fontSize(20)
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .fontColor([this.palette().text])
      }
      .justifyContent(FlexAlign.Center)
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.palette().subtle)
      .onClick(() => {
        this.aboutController.open();
      })

      Row() {
        SymbolGlyph(this.isDark ? $r('sys.symbol.sun_max') : $r('sys.symbol.moon'))
          .fontSize(20)
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .fontColor([this.palette().text])
      }
      .justifyContent(FlexAlign.Center)
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.palette().subtle)
      .onClick(() => {
        this.isDark = !this.isDark;
        this.persist();
        this.applySystemBars();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: this.topInset + 8, bottom: 8 })
    .backgroundColor(this.isDark ? '#73000000' : '#73F1F3F5')
    .backgroundBlurStyle(this.isDark ? BlurStyle.BACKGROUND_THIN : BlurStyle.BACKGROUND_THIN,
      { colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT })
  }

  @Builder
  tabItem(label: string, symbol: Resource, index: number) {
    Column({ space: 2 }) {
      SymbolGlyph(symbol)
        .fontSize(20)
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor([this.curTab === index ? this.palette().accent : this.palette().muted])
      Text(label)
        .fontSize(10)
        .fontWeight(this.curTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.curTab === index ? this.palette().accent : this.palette().muted)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      this.backdrop()

      Tabs({ barPosition: BarPosition.End, index: this.curTab, controller: this.tabsController }) {
        TabContent() {
          this.entryTab()
        }
        .tabBar(this.tabItem('录入', $r('sys.symbol.pencil_line'), 0))

        TabContent() {
          this.voyageTab()
        }
        .tabBar(this.tabItem('航次', $r('sys.symbol.compass'), 1))

        TabContent() {
          this.summaryTab()
        }
        .tabBar(this.tabItem('汇总', $r('sys.symbol.square_grid_2x2'), 2))

        TabContent() {
          this.noonTab()
        }
        .tabBar(this.tabItem('正午', $r('sys.symbol.sun_max'), 3))

        TabContent() {
          this.recordsTab()
        }
        .tabBar(this.tabItem('明细', $r('sys.symbol.list_bullet'), 4))
      }
      .onChange((index: number) => {
        this.curTab = index;
      })
      .opacity(this.tabFade)
      .translate({ x: this.tabX })
      .barHeight(0)
      .barBackgroundColor(Color.Transparent)
      .scrollable(true)
      .width('100%')
      .height('100%')

      Column() {
        this.appHeader()
        Column()
          .width('100%')
          .height(14)
          .linearGradient({
            angle: 180,
            colors: [[this.isDark ? '#000000' : '#F1F3F5', 0.0],
              [this.isDark ? '#00000000' : '#00F1F3F5', 1.0]]
          })
      }
      .width('100%')
      .position({ x: 0, y: 0 })

      this.pillBar()
    }
  }
}
