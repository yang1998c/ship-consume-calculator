/**
 * 携带状态的输入/展示组件。
 * 用 @Component + @Prop 而不是 @Builder：@Builder 按值传参不随状态刷新，
 * 会导致时间显示、时区选择、航次结果停留在首次渲染的旧值。
 */
import { fmtDuration, fmtHM, fmtOffset, formatWall, TZ_OFFSETS } from '../model/Calc';
import { NO_TIME } from '../model/Types';
import { Palette, Palettes } from '../model/Theme';

@Component
export struct DateTimeField {
  @Prop wall: number = NO_TIME;
  @Prop isDark: boolean = false;
  @Prop weighted: boolean = false;
  onTap: () => void = () => {
  };

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  build() {
    Row() {
      Text(this.wall === NO_TIME ? '点击选择' : formatWall(this.wall))
        .fontSize(14)
        .fontColor(this.wall === NO_TIME ? this.palette().muted : this.palette().heading)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('▾')
        .fontSize(12)
        .fontColor(this.palette().muted)
        .margin({ left: 4 })
    }
    .width(this.weighted ? 'auto' : '100%')
    .layoutWeight(this.weighted ? 1 : 0)
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.palette().inputBg)
    .borderRadius(12)
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
export struct OffsetSelect {
  @Prop off: number = 0;
  @Prop isDark: boolean = false;
  onPick: (index: number) => void = () => {
  };

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  private options(): SelectOption[] {
    const opts: SelectOption[] = [];
    for (let i: number = 0; i < TZ_OFFSETS.length; i++) {
      opts.push({ value: fmtOffset(TZ_OFFSETS[i]) });
    }
    return opts;
  }

  private index(): number {
    let best: number = 0;
    let bd: number = Infinity;
    for (let i: number = 0; i < TZ_OFFSETS.length; i++) {
      const d: number = Math.abs(TZ_OFFSETS[i] - this.off);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  build() {
    Select(this.options())
      .selected(this.index())
      .value(fmtOffset(this.off))
      .font({ size: 11 })
      .fontColor(this.palette().accent)
      .selectedOptionFont({ size: 13 })
      .optionFont({ size: 13 })
      .optionWidth(132)
      .height(38)
      .width(104)
      .backgroundColor(this.palette().subtle)
      .borderRadius(12)
      .onSelect((index: number) => {
        this.onPick(index);
      })
  }
}

@Component
export struct OilInput {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop isDark: boolean = false;
  onInput: (v: string) => void = () => {
  };

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  build() {
    Row({ space: 10 }) {
      Text(this.label)
        .fontSize(13)
        .fontColor(this.palette().text)
        .layoutWeight(1)
      TextInput({ text: this.value, placeholder: '0.000' })
        .type(InputType.NUMBER_DECIMAL)
        .fontSize(15)
        .fontColor(this.palette().heading)
        .placeholderColor(this.palette().muted)
        .backgroundColor(this.palette().inputBg)
        .borderRadius(12)
        .height(40)
        .width(130)
        .textAlign(TextAlign.End)
        .onChange((v: string) => {
          this.onInput(v);
        })
    }
    .width('100%')
  }
}

@Component
export struct ResultChip {
  @Prop label: string = '';
  @Prop ms: number = NO_TIME;
  @Prop isDark: boolean = false;
  @Prop primary: boolean = false;

  private palette(): Palette {
    return this.isDark ? Palettes.DARK : Palettes.LIGHT;
  }

  build() {
    Column({ space: 2 }) {
      Text(this.label)
        .fontSize(11)
        .fontColor(this.palette().muted)
      if (this.ms === NO_TIME) {
        Text('—')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().muted)
        Text('等待填写时间节点')
          .fontSize(9)
          .fontColor(this.palette().muted)
      } else {
        Row({ space: 3 }) {
          Text(fmtDuration(this.ms).totalHours.toFixed(2))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.palette().heading)
          Text('小时')
            .fontSize(9)
            .fontColor(this.palette().muted)
            .margin({ bottom: 3 })
        }
        .alignItems(VerticalAlign.Bottom)
        Text(`${fmtDuration(this.ms).text}（${fmtHM(this.ms)}）`)
          .fontSize(9)
          .fontColor(this.palette().muted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .layoutWeight(1)
    .padding(10)
    .backgroundColor(this.palette().subtle)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }
}
