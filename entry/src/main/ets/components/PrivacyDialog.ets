/**
 * 隐私合规弹窗
 * - PrivacyGateDialog：首次启动的同意门禁，必须明确选择
 * - PolicyViewDialog：从「关于与反馈」查看全文
 */
import { Palette, Palettes } from '../model/Theme';
import { AGREEMENT_TEXT, PRIVACY_SUMMARY, PRIVACY_TEXT, PRIVACY_TITLE } from '../model/Legal';

@CustomDialog
export struct PrivacyGateDialog {
  controller?: CustomDialogController;
  @Link isDark: boolean;
  onAgree: () => void = () => {
  };
  onReject: () => void = () => {
  };

  @State showFull: boolean = false;

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  build() {
    Column({ space: 10 }) {
      Text(PRIVACY_TITLE)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.palette().heading)
        .width('100%')

      Scroll() {
        Column({ space: 10 }) {
          Text(PRIVACY_SUMMARY)
            .fontSize(13)
            .lineHeight(21)
            .fontColor(this.palette().text)
            .width('100%')

          if (this.showFull) {
            Text(AGREEMENT_TEXT)
              .fontSize(12)
              .lineHeight(19)
              .fontColor(this.palette().muted)
              .width('100%')
            Text(PRIVACY_TEXT)
              .fontSize(12)
              .lineHeight(19)
              .fontColor(this.palette().muted)
              .width('100%')
          }

          Text(this.showFull ? '收起全文 ▴' : '查看完整全文 ▾')
            .fontSize(12)
            .fontColor(this.palette().accent)
            .width('100%')
            .padding({ top: 4, bottom: 4 })
            .onClick(() => {
              this.showFull = !this.showFull;
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .align(Alignment.Top)

      Row({ space: 10 }) {
        Button('不同意并退出')
          .fontSize(14)
          .fontColor(this.palette().danger)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: this.palette().dangerBorder })
          .borderRadius(12)
          .height(44)
          .layoutWeight(1)
          .onClick(() => {
            this.onReject();
          })
        Button('同意并继续')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().onAccent)
          .backgroundColor(this.palette().accent)
          .borderRadius(12)
          .height(44)
          .layoutWeight(1)
          .onClick(() => {
            this.onAgree();
          })
      }
      .width('100%')
    }
    .width('92%')
    .height('74%')
    .padding(18)
    .backgroundColor(this.palette().glassSolid)
    .border({ width: 1, color: this.palette().glassBorder })
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK,
      { colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT })
    .shadow({ radius: 24, color: this.palette().cardShadow, offsetY: 10 })
    .borderRadius(24)
  }
}

@CustomDialog
export struct PolicyViewDialog {
  controller?: CustomDialogController;
  @Link isDark: boolean;

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(PRIVACY_TITLE)
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

      Scroll() {
        Column({ space: 12 }) {
          Text(PRIVACY_TEXT)
            .fontSize(12)
            .lineHeight(19)
            .fontColor(this.palette().text)
            .width('100%')
          Text(AGREEMENT_TEXT)
            .fontSize(12)
            .lineHeight(19)
            .fontColor(this.palette().text)
            .width('100%')
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
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
    .height('76%')
    .padding(18)
    .backgroundColor(this.palette().glassSolid)
    .border({ width: 1, color: this.palette().glassBorder })
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK,
      { colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT })
    .shadow({ radius: 24, color: this.palette().cardShadow, offsetY: 10 })
    .borderRadius(24)
  }
}
