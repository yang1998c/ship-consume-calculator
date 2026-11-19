/**
 * 关于与反馈
 * 联系方式、开源依赖说明与许可条款。
 */
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { bundleManager } from '@kit.AbilityKit';
import { Palette, Palettes } from '../model/Theme';

const AUTHOR: string = 'KOKORO Yang';
const QQ: string = '908903491';
const EMAIL: string = '908903491@qq.com';


const OS_NOTE: string =
  '· 框架：HarmonyOS ArkUI（ArkTS）\n\n' +
  '· 项目：船舶能耗计算器\n' +
  '开源地址 github.com/yang1998c/ship-consume-calculator\n\n' +
  '· 计算口径移植自同作者的网页版同名工具。';

const FEEDBACK_NOTE: string =
  '本工具为简便计算填报能耗数据而开发；本应用无联网功能，' +
  '数据全部本地计算无需上云；因无法考虑到各船型和任务的需要，' +
  '如有使用中遇到的问题与不便欢迎反馈。';

const LICENSE_TEXT: string =
  'Copyright (c) 2026 KOKORO Yang\n\n' +
  '本软件采用 PolyForm Noncommercial License 1.0.0。\n\n' +
  '允许：个人学习、研究、自用；非营利组织与教育机构内部使用；' +
  '阅读与修改源码（修改后再分发需保留同一许可）。\n\n' +
  '禁止：任何商业目的的使用，包括但不限于销售、随商品捆绑、' +
  '作为商业服务的一部分、在公司生产环境中使用。\n\n' +
  '完整许可文本见项目仓库 LICENSE 文件，或访问\n' +
  'polyformproject.org/licenses/noncommercial/1.0.0\n\n' +
  '商业授权请联系：908903491@qq.com';

@CustomDialog
export struct AboutDialog {
  controller?: CustomDialogController;
  @Link isDark: boolean;
  @State appVersion: string = '';
  onShowPolicy: () => void = () => {
  };
  onShowLicense: () => void = () => {
  };

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  private copy(text: string, label: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data).then(() => {
        promptAction.showToast({ message: `已复制${label}`, duration: 1600 });
      }).catch(() => {
        promptAction.showToast({ message: '复制失败', duration: 1600 });
      });
    } catch (e) {
      promptAction.showToast({ message: '复制失败', duration: 1600 });
    }
  }

  @Builder
  contactRow(label: string, value: string, copyable: boolean) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(12)
        .fontColor(this.palette().muted)
        .width(56)
      Text(value)
        .fontSize(14)
        .fontColor(this.palette().heading)
        .layoutWeight(1)
      if (copyable) {
        Text('复制')
          .fontSize(11)
          .fontColor(this.palette().accent)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(6)
          .backgroundColor(this.palette().subtle)
          .onClick(() => {
            this.copy(value, label);
          })
      }
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  blockTitle(text: string, kicker: string) {
    Row({ space: 6 }) {
      Text(text)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.palette().heading)
        .layoutWeight(1)
      Text(kicker)
        .fontSize(9)
        .fontColor(this.palette().muted)
        .letterSpacing(0.5)
    }
    .width('100%')
    .margin({ top: 4 })
  }

  aboutToAppear(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersion = info.versionName;
    } catch (e) {
      this.appVersion = '1.0.3';
    }
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('关于与反馈')
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
        Column({ space: 10 }) {
          // ---- 作者 / 联系方式 ----
          Column() {
            Row({ space: 10 }) {
              Column() {
                Text(AUTHOR)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.palette().heading)
                Text(`船舶能耗计算器 v${this.appVersion}`)
                  .fontSize(11)
                  .fontColor(this.palette().muted)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            Divider()
              .color(this.palette().line)
              .margin({ top: 8, bottom: 4 })

            this.contactRow('QQ', QQ, true)
            this.contactRow('电子邮件', EMAIL, true)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.palette().subtle)
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // ---- 作者的话 / 反馈征集 ----
          Column({ space: 8 }) {
            Row({ space: 6 }) {
              Text('作者的话')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.palette().heading)
              Text('FEEDBACK')
                .fontSize(10)
                .fontColor(this.palette().accent)
                .letterSpacing(0.5)
            }
            .width('100%')

            Text(FEEDBACK_NOTE)
              .fontSize(12)
              .lineHeight(19)
              .fontColor(this.palette().text)
              .width('100%')

            Text('点上方 QQ 或邮箱可直接复制')
              .fontSize(10)
              .fontColor(this.palette().muted)
              .width('100%')
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.isDark ? '#1A317AF7' : '#0F0A59F7')
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // ---- 开源说明 ----
          this.blockTitle('开源代码与致谢', 'OPEN SOURCE')
          Text(OS_NOTE)
            .fontSize(12)
            .lineHeight(19)
            .fontColor(this.palette().text)
            .width('100%')

          // ---- 隐私政策入口 ----
          Row() {
            Text('隐私政策与用户协议')
              .fontSize(13)
              .fontColor(this.palette().accent)
              .layoutWeight(1)
            Text('›')
              .fontSize(15)
              .fontColor(this.palette().muted)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.palette().subtle)
          .borderRadius(12)
          .onClick(() => {
            this.onShowPolicy();
          })

          // ---- 许可 ----
          this.blockTitle('许可条款', 'LICENSE')
          Text(LICENSE_TEXT)
            .fontSize(11)
            .lineHeight(17)
            .fontColor(this.palette().muted)
            .width('100%')
            .padding(12)
            .backgroundColor(this.palette().subtle)
            .borderRadius(12)

          Row() {
            Text('查看许可全文')
              .fontSize(13)
              .fontColor(this.palette().accent)
              .layoutWeight(1)
            Text('›')
              .fontSize(15)
              .fontColor(this.palette().muted)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.palette().subtle)
          .borderRadius(12)
          .onClick(() => {
            this.onShowLicense();
          })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .align(Alignment.Top)

      Button('知道了')
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
    
    .shadow({ radius: 24, color: this.palette().cardShadow, offsetY: 10 })
    .borderRadius(32)
  }
}
