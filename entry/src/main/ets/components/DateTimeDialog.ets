/**
 * 船钟时间选择器（日期 + 时间，24 小时制）
 * 内部用「本地字段承载」的 Date 与 DatePicker/TimePicker 交互，
 * 确认时再换算成 UTC 锚定的船钟墙钟毫秒，避开时区歧义。
 */
import { formatWall, partsOfWall, wallToMs } from '../model/Calc';
import { Palette, Palettes } from '../model/Theme';

@CustomDialog
export struct DateTimeDialog {
  controller?: CustomDialogController;
  @Link wall: number;
  @Link isDark: boolean;
  onConfirm: (wallMs: number) => void = () => {
  };

  @State picked: Date = new Date(2000, 0, 1, 0, 0, 0);

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  aboutToAppear(): void {
    const p = partsOfWall(this.wall);
    this.picked = new Date(p.y, p.mo - 1, p.d, p.h, p.mi, p.s);
  }

  private withDate(y: number, mo: number, d: number): Date {
    return new Date(y, mo, d, this.picked.getHours(), this.picked.getMinutes(), this.picked.getSeconds());
  }

  private withTime(h: number, mi: number, s: number): Date {
    return new Date(this.picked.getFullYear(), this.picked.getMonth(), this.picked.getDate(), h, mi, s);
  }

  @Builder
  actionButton(label: string, primary: boolean, action: () => void) {
    Button(label)
      .fontSize(15)
      .fontColor(primary ? this.palette().onAccent : this.palette().text)
      .backgroundColor(primary ? this.palette().accent : Color.Transparent)
      .borderWidth(primary ? 0 : 1)
      .borderColor(this.palette().outlineBorder)
      .borderRadius(10)
      .height(40)
      .layoutWeight(1)
      .onClick(action)
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('选择时间（船钟）')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().heading)
          .layoutWeight(1)
        Button('现在')
          .fontSize(13)
          .fontColor(this.palette().accent)
          .backgroundColor(this.palette().subtle)
          .borderRadius(8)
          .height(30)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            const n = new Date();
            this.picked = new Date(n.getFullYear(), n.getMonth(), n.getDate(),
              n.getHours(), n.getMinutes(), n.getSeconds());
          })
      }
      .width('100%')

      Text(formatWall(wallToMs(this.picked.getFullYear(), this.picked.getMonth() + 1,
        this.picked.getDate(), this.picked.getHours(), this.picked.getMinutes(), this.picked.getSeconds())))
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().heading)
        .width('100%')
        .textAlign(TextAlign.Center)

      DatePicker({
        start: new Date(2000, 0, 1),
        end: new Date(2100, 11, 31),
        selected: this.picked
      })
        .height(160)
        .width('100%')
        .textStyle({ color: this.palette().muted, font: { size: 16 } })
        .selectedTextStyle({ color: this.palette().accent, font: { size: 19, weight: FontWeight.Bold } })
        .disappearTextStyle({ color: this.palette().muted, font: { size: 13 } })
        .onDateChange((value: Date) => {
          this.picked = this.withDate(value.getFullYear(), value.getMonth(), value.getDate());
        })

      TimePicker({
        selected: this.picked,
        format: TimePickerFormat.HOUR_MINUTE_SECOND
      })
        .height(110)
        .width('100%')
        .textStyle({ color: this.palette().muted, font: { size: 16 } })
        .selectedTextStyle({ color: this.palette().accent, font: { size: 19, weight: FontWeight.Bold } })
        .disappearTextStyle({ color: this.palette().muted, font: { size: 13 } })
        .onChange((value: TimePickerResult) => {
          const sec: number = value.second === undefined ? 0 : value.second;
          this.picked = this.withTime(value.hour, value.minute, sec);
        })

      Row({ space: 10 }) {
        this.actionButton('取消', false, () => {
          this.controller?.close();
        })
        this.actionButton('确定', true, () => {
          const wallMs = wallToMs(this.picked.getFullYear(), this.picked.getMonth() + 1,
            this.picked.getDate(), this.picked.getHours(), this.picked.getMinutes(), this.picked.getSeconds());
          this.onConfirm(wallMs);
          this.controller?.close();
        })
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('92%')
    .padding(18)
    .backgroundColor(this.palette().glassCard)
    .border({ width: 1, color: this.palette().glassBorder })
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK,
      { colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT })
    .shadow({ radius: 24, color: this.palette().cardShadow, offsetY: 10 })
    .shadow({ radius: 24, color: this.palette().cardShadow, offsetY: 10 })
    .borderRadius(20)
  }
}
