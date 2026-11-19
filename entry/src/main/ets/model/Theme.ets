/**
 * 船舶能耗计算器 —— 配色（海图 / 夜间值守 两套）
 */
import { ShipStatus } from './Types';

export class Palette {
  // —— HarmonyOS Design 系统色板（浅色）——
  paper: string = '#F1F3F5';
  paperAlt: string = '#F1F3F5';
  glowA: string = '#00FFFFFF';
  glowB: string = '#00FFFFFF';
  card: string = '#FFFFFF';
  subtle: string = '#F1F3F5';
  line: string = '#1A182431';
  lineStrong: string = '#33182431';
  heading: string = '#182431';
  text: string = '#182431';
  muted: string = '#99182431';
  accent: string = '#0A59F7';
  onAccent: string = '#FFFFFF';
  signal: string = '#ED6F21';
  inputBg: string = '#F1F3F5';
  fuelBg: string = '#FFF3E3';
  fuelBorder: string = '#FFE0B8';
  fuelText: string = '#B25E00';
  ok: string = '#64BB5C';
  danger: string = '#E84026';
  dangerBorder: string = '#00FFFFFF';
  outlineBorder: string = '#1A182431';
  /** 磨砂玻璃表面（半透明 + 背景模糊） */
  glassCard: string = '#FFFFFF';
  glassBorder: string = '#1A182431';
  glassBar: string = '#F2FFFFFF';
  /** 需要压住正文的浮层（关于弹窗等）用更实的底 */
  glassSolid: string = '#FFFFFF';
  cardShadow: string = '#0D000000';

  statusColor(key: ShipStatus): string {
    switch (key) {
      case ShipStatus.Sailing: return this.isDark ? '#5C9BFF' : '#0A59F7';
      case ShipStatus.Anchorage: return this.isDark ? '#FF9A52' : '#ED6F21';
      case ShipStatus.Drifting: return this.isDark ? '#3ECFD8' : '#0AA6B8';
      case ShipStatus.Berthing: return this.isDark ? '#7BD273' : '#4CA345';
      case ShipStatus.Buoy: return this.isDark ? '#A98BFF' : '#8A5CF6';
      default: return this.isDark ? '#5C9BFF' : '#0A59F7';
    }
  }

  statusSoft(key: ShipStatus): string {
    switch (key) {
      case ShipStatus.Sailing: return this.isDark ? '#12294D' : '#E8F0FE';
      case ShipStatus.Anchorage: return this.isDark ? '#3A2413' : '#FDF0E4';
      case ShipStatus.Drifting: return this.isDark ? '#0E3438' : '#E4F6F8';
      case ShipStatus.Berthing: return this.isDark ? '#17331A' : '#EBF6E9';
      case ShipStatus.Buoy: return this.isDark ? '#241B45' : '#F0EBFF';
      default: return this.isDark ? '#12294D' : '#E8F0FE';
    }
  }

  statusInk(key: ShipStatus): string {
    switch (key) {
      case ShipStatus.Sailing: return this.isDark ? '#9CC4FF' : '#0A59F7';
      case ShipStatus.Anchorage: return this.isDark ? '#FFC08A' : '#C25A0A';
      case ShipStatus.Drifting: return this.isDark ? '#7FE3EA' : '#00797F';
      case ShipStatus.Berthing: return this.isDark ? '#A6E39F' : '#3E8C36';
      case ShipStatus.Buoy: return this.isDark ? '#C9B6FF' : '#6A42D9';
      default: return this.isDark ? '#9CC4FF' : '#0A59F7';
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
    p.paper = '#F1F3F5';
    p.paperAlt = '#F1F3F5';
    p.glowA = '#00FFFFFF';
    p.glowB = '#00FFFFFF';
    p.card = '#FFFFFF';
    p.subtle = '#F1F3F5';
    p.line = '#1A182431';
    p.lineStrong = '#33182431';
    p.heading = '#182431';
    p.text = '#182431';
    p.muted = '#99182431';
    p.accent = '#0A59F7';
    p.onAccent = '#FFFFFF';
    p.signal = '#ED6F21';
    p.inputBg = '#F1F3F5';
    p.fuelBg = '#FFF3E3';
    p.fuelBorder = '#FFE0B8';
    p.fuelText = '#B25E00';
    p.ok = '#64BB5C';
    p.danger = '#E84026';
    p.dangerBorder = '#00FFFFFF';
    p.outlineBorder = '#1A182431';
    p.glassCard = '#FFFFFF';
    p.glassBorder = '#1A182431';
    p.glassBar = '#F2FFFFFF';
    p.glassSolid = '#FFFFFF';
    p.cardShadow = '#0D000000';
    return p;
  }

  private static buildDark(): Palette {
    const p = new Palette();
    p.isDark = true;
    p.paper = '#000000';
    p.paperAlt = '#000000';
    p.glowA = '#00000000';
    p.glowB = '#00000000';
    p.card = '#1F1F1F';
    p.subtle = '#2A2A2A';
    p.line = '#33FFFFFF';
    p.lineStrong = '#4DFFFFFF';
    p.heading = '#E5FFFFFF';
    p.text = '#E5FFFFFF';
    p.muted = '#99FFFFFF';
    p.accent = '#317AF7';
    p.onAccent = '#FFFFFF';
    p.signal = '#FF9A52';
    p.inputBg = '#2A2A2A';
    p.fuelBg = '#3A2A14';
    p.fuelBorder = '#5C4420';
    p.fuelText = '#FFC08A';
    p.ok = '#7BD273';
    p.danger = '#FF6B57';
    p.dangerBorder = '#00FFFFFF';
    p.outlineBorder = '#33FFFFFF';
    p.glassCard = '#FF1F1F1F';
    p.glassBorder = '#33FFFFFF';
    p.glassBar = '#CC1F1F1F';
    p.glassSolid = '#FF1F1F1F';
    p.cardShadow = '#40000000';
    return p;
  }
}
