/**
 * 使用方法
 */
import { Palette, Palettes } from '../model/Theme';

class HelpSection {
  title: string = '';
  lines: string[] = [];

  constructor(title: string, lines: string[]) {
    this.title = title;
    this.lines = lines;
  }
}

const SECTIONS: HelpSection[] = [
  new HelpSection('一、三步上手', [
    '1. 先到「明细」点「保存备份」，留一份初始数据，随时可恢复。',
    '2. 到「录入」按船钟时间逐段填写时间区间。',
    '3. 到「汇总」「正午」核对统计，确认无误后「导出 Excel」上报。'
  ]),
  new HelpSection('二、录入', [
    '· 起止时间填的是「当地船钟」，不是 UTC。',
    '· 船钟时区按船上实际拨钟选择；跨时区时，开始和结束可以不同。',
    '· 状态五选一：航行 / 锚泊 / 漂航 / 靠泊 / 系浮筒。',
    '· 备注可写航段或港名，便于日后核对。',
    '· 添加一条后，本段结束时间会自动带入下一段开始，连续录入更省事。'
  ]),
  new HelpSection('三、航次', [
    '· 填三个时间点：上次抵港、上次离港、本次抵港。',
    '· 填五项存油：上次抵港、上次离港、本次抵港、燃油添加量、燃油驳出量。',
    '· 航行时间 = 本次抵港 − 上次离港。',
    '· 营运时间 = 本次抵港 − 上次抵港。',
    '· 上一港在港时间 = 上次离港 − 上次抵港。',
    '· 燃油实际消耗 = 上次抵港存油 + 添加量 − 驳出量 − 本次抵港存油。'
  ]),
  new HelpSection('四、营运时间核对（重点）', [
    '营运时间有两种算法，结果应当一致：',
    '① 抵港时间差：本次抵港 − 上次抵港。',
    '② 录入区间合计：该时段内所有时间区间的时长之和。',
    '两者不一致时，航次页「核算结果」会用红字提示，并给出两个数字与差值。',
    '常见原因：区间漏录、时间点填错、拨钟后未同步修改、区间跨出该时段。',
    '差值在 1 分钟以内不提示（时间精度到分钟）。'
  ]),
  new HelpSection('五、正午', [
    '· 以船钟每天 12:00 为切分点，把整个统计区间切成若干段。',
    '· 可直接点「按记录填充」，用现有区间自动确定起止时间。',
    '· 表格逐段列出五种状态的时长，段末给出小计。',
    '· 存在缺口或重叠时会单独提示，便于核对。'
  ]),
  new HelpSection('六、汇总', [
    '· 上方是五种状态的时长卡片：小时、天时分秒、hh:mm、占比条。',
    '· 下方设置各状态油耗率（吨/小时），自动算出预计总能耗。',
    '· 油耗率会随数据一起保存，下次打开仍在。'
  ]),
  new HelpSection('七、备份与 Excel', [
    '· 保存备份：生成 .json 文件，恢复时会连同航次信息与油耗率一起还原。',
    '· 导出 Excel：四张表——时间区间明细 / 航次统计 / 时间汇总 / 油耗参数。',
    '· 导入 Excel：按「时间区间明细」恢复区间，若含航次统计、油耗参数也会一并更新。',
    '· 下载模板：给空白表格，最后一页「填写说明」写了每列怎么填。',
    '· 导入会替换现有全部区间，操作前请先保存备份。'
  ]),
  new HelpSection('八、常见问题', [
    '· 时间只有分钟，没有秒：录入和导入都会按分钟取整。',
    '· 跨时区记录导出后再导入，会按本机时区解释；如需无损往返，在表格右侧自行补充「开始时区 / 结束时区」两列，导入端已支持。',
    '· 所有数据只存在本机，无联网、不上传。换机前请先导出备份或 Excel。'
  ])
];

@CustomDialog
export struct HelpDialog {
  controller?: CustomDialogController;
  @Link isDark: boolean;

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('使用方法')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().heading)
          .layoutWeight(1)
        Text('✕')
          .fontSize(15)
          .fontColor(this.palette().muted)
          .padding(6)
          .onClick(() => {
            this.controller?.close();
          })
      }
      .width('100%')

      Scroll() {
        Column({ space: 14 }) {
          ForEach(SECTIONS, (sec: HelpSection) => {
            Column({ space: 6 }) {
              Text(sec.title)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.palette().heading)
                .width('100%')
              ForEach(sec.lines, (line: string) => {
                Text(line)
                  .fontSize(12)
                  .lineHeight(20)
                  .fontColor(this.palette().text)
                  .width('100%')
              }, (line: string) => line)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (sec: HelpSection) => sec.title)
        }
        .width('100%')
        .padding({ bottom: 6 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })

      Button('知道了')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().onAccent)
        .backgroundColor(this.palette().accent)
        .borderRadius(22)
        .height(44)
        .width('100%')
        .onClick(() => {
          this.controller?.close();
        })
    }
    .width('92%')
    .height('84%')
    .padding(18)
    .backgroundColor(this.palette().glassSolid)
    .borderRadius(32)
  }
}
