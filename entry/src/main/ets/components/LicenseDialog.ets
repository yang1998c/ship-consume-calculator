/**
 * 许可全文弹窗（PolyForm Noncommercial 1.0.0）
 */
import { Palette, Palettes } from '../model/Theme';
import { LICENSE_FULL, LICENSE_TITLE, LICENSE_URL } from '../model/Legal';

@CustomDialog
export struct LicenseDialog {
  controller?: CustomDialogController;
  @Link isDark: boolean;

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('许可全文')
          .fontSize(17)
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

      Text('Copyright (c) 2026 KOKORO Yang')
        .fontSize(11)
        .fontColor(this.palette().text)
        .width('100%')

      Text(`${LICENSE_TITLE} · ${LICENSE_URL}`)
        .fontSize(10)
        .fontColor(this.palette().muted)
        .width('100%')

      Scroll() {
        Text(LICENSE_FULL)
          .fontSize(11)
          .lineHeight(18)
          .fontColor(this.palette().text)
          .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .align(Alignment.Top)

      Button('关闭')
        .fontSize(15)
        .fontColor(this.palette().onAccent)
        .backgroundColor(this.palette().accent)
        .borderRadius(12)
        .height(44)
        .width('100%')
        .onClick(() => {
          this.controller?.close();
        })
    }
    .width('92%')
    .height('80%')
    .padding(18)
    .backgroundColor(this.palette().glassSolid)
    .border({ width: 1, color: this.palette().glassBorder })
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK,
      { colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT })
    .shadow({ radius: 24, color: this.palette().cardShadow, offsetY: 10 })
    .borderRadius(24)
  }
}
