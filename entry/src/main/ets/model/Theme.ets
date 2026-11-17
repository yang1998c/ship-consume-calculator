/**
 * 船舶能耗计算器 —— 配色（海图 / 夜间值守 两套）
 */
import { ShipStatus } from './Types';

export class Palette {
  paper: string = '#e8e2d3';
  /** 背景渐变的下缘色，给磨砂层提供层次 */
  paperAlt: string = '#efe8d8';
  /** 两处柔光晕，作为沉浸光感的底色 */
  glowA: string = '#3315486E';
  glowB: string = '#26C8821C';
  card: string = '#fbf8f0';
  subtle: string = '#f3eee0';
  line: string = '#d2c8ae';
  lineStrong: string = '#b9a984';
  heading: string = '#10233a';
  text: string = '#26333f';
  muted: string = '#706854';
  accent: string = '#15486e';
  onAccent: string = '#fbf8f0';
  signal: string = '#c8821c';
  inputBg: string = '#fffefa';
  fuelBg: string = '#f7ecd0';
  fuelBorder: string = '#e2c98d';
  fuelText: string = '#85560f';
  ok: string = '#2e7d46';
  danger: string = '#b2372a';
  dangerBorder: string = '#ddb3aa';
  outlineBorder: string = '#b6a985';
  /** 磨砂玻璃表面（半透明 + 背景模糊） */
  glassCard: string = '#D9FBF8F0';
  glassBorder: string = '#8CB9A984';
  glassBar: string = '#D9F7F2E6';
  /** 需要压住正文的浮层（关于弹窗等）用更实的底 */
  glassSolid: string = '#F7FBF8F0';
  cardShadow: string = '#1A0C2036';

  statusColor(key: ShipStatus): string {
    switch (key) {
      case ShipStatus.Sailing: return this.isDark ? '#74abe2' : '#2b6cb0';
      case ShipStatus.Anchorage: return this.isDark ? '#dfa244' : '#b87014';
      case ShipStatus.Drifting: return this.isDark ? '#49bfc0' : '#0d8386';
      case ShipStatus.Berthing: return this.isDark ? '#60be7c' : '#3a8650';
      case ShipStatus.Buoy: return this.isDark ? '#a98fe7' : '#7456bd';
      default: return this.isDark ? '#74abe2' : '#2b6cb0';
    }
  }

  statusSoft(key: ShipStatus): string {
    switch (key) {
      case ShipStatus.Sailing: return this.isDark ? '#17283c' : '#e4edf6';
      case ShipStatus.Anchorage: return this.isDark ? '#34281a' : '#f6e9d0';
      case ShipStatus.Drifting: return this.isDark ? '#103133' : '#daf0ef';
      case ShipStatus.Berthing: return this.isDark ? '#143021' : '#e1f1e4';
      case ShipStatus.Buoy: return this.isDark ? '#262040' : '#ece7f8';
      default: return this.isDark ? '#17283c' : '#e4edf6';
    }
  }

  statusInk(key: ShipStatus): string {
    switch (key) {
      case ShipStatus.Sailing: return this.isDark ? '#a5c8ee' : '#1d4f84';
      case ShipStatus.Anchorage: return this.isDark ? '#ecc076' : '#8a5410';
      case ShipStatus.Drifting: return this.isDark ? '#7fd7d3' : '#0a6063';
      case ShipStatus.Berthing: return this.isDark ? '#90d9a8' : '#296339';
      case ShipStatus.Buoy: return this.isDark ? '#c6b2f1' : '#563b95';
      default: return this.isDark ? '#a5c8ee' : '#1d4f84';
    }
  }

  isDark: boolean = false;
}

export class Palettes {
  static readonly LIGHT: Palette = Palettes.buildLight();
  static readonly DARK: Palette = Palettes.buildDark();

  private static buildLight(): Palette {
    const p = new Palette();
    p.isDark = false;
    p.paper = '#e8e2d3';
    p.paperAlt = '#f1eadb';
    p.glowA = '#3315486E';
    p.glowB = '#26C8821C';
    p.card = '#fbf8f0';
    p.subtle = '#f3eee0';
    p.line = '#d2c8ae';
    p.lineStrong = '#b9a984';
    p.heading = '#10233a';
    p.text = '#26333f';
    p.muted = '#706854';
    p.accent = '#15486e';
    p.onAccent = '#fbf8f0';
    p.signal = '#c8821c';
    p.inputBg = '#fffefa';
    p.fuelBg = '#f7ecd0';
    p.fuelBorder = '#e2c98d';
    p.fuelText = '#85560f';
    p.ok = '#2e7d46';
    p.danger = '#b2372a';
    p.dangerBorder = '#ddb3aa';
    p.outlineBorder = '#b6a985';
    p.glassCard = '#D9FBF8F0';
    p.glassBorder = '#8CB9A984';
    p.glassBar = '#D9F7F2E6';
    p.glassSolid = '#F7FBF8F0';
    p.cardShadow = '#1A0C2036';
    return p;
  }

  private static buildDark(): Palette {
    const p = new Palette();
    p.isDark = true;
    p.paper = '#0a111d';
    p.paperAlt = '#101c30';
    p.glowA = '#4D7FB0E4';
    p.glowB = '#33E0A448';
    p.card = '#131e30';
    p.subtle = '#18253a';
    p.line = '#28374e';
    p.lineStrong = '#3c4e69';
    p.heading = '#f0f5fc';
    p.text = '#dce4ef';
    p.muted = '#91a2ba';
    p.accent = '#7fb0e4';
    p.onAccent = '#0a1525';
    p.signal = '#e0a448';
    p.inputBg = '#0f192a';
    p.fuelBg = '#2b220f';
    p.fuelBorder = '#5c4b1d';
    p.fuelText = '#e9bb61';
    p.ok = '#62bd7e';
    p.danger = '#e07060';
    p.dangerBorder = '#61302a';
    p.outlineBorder = '#3a4c68';
    p.glassCard = '#CC0F1B2B';
    p.glassBorder = '#663C4E69';
    p.glassBar = '#D90B1524';
    p.glassSolid = '#F70F1B2B';
    p.cardShadow = '#66000000';
    return p;
  }
}
