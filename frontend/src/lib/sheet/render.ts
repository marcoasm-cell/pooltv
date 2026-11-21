// Draws a game sheet ("ficha de jogo") as an A4 PDF. Plain data in, jsPDF out:
// no app state here, so it can run anywhere (and be tried out in Node).
import type { jsPDF as JsPDF } from 'jspdf';

export type SheetSide = 'home' | 'away';

export interface SheetPlayer {
	/** "1".."4" for a starter, "S1".. for a substitute */
	n: string;
	name: string;
	won: number;
	lost: number;
	sub: boolean;
}

export interface SheetRow {
	n: string;
	home: string;
	away: string;
	/** Empty while the game is not played */
	score: string;
	winner: SheetSide | null;
}

export interface SheetModel {
	title: string;
	subtitle: string;
	date: string;
	home: { name: string; score: number };
	away: { name: string; score: number };
	winner: SheetSide | null;
	/** "X vence o jogo", "Empate", or empty while it is on */
	result: string;
	/** Players of each team with their wins and losses (team matches) */
	rosters: { home: SheetPlayer[]; away: SheetPlayer[] } | null;
	blocks: { title: string; rows: SheetRow[] }[];
	labels: { won: string; lost: string };
}

type RGB = [number, number, number];
const INK: RGB = [23, 23, 22];
const MUTED: RGB = [140, 140, 136];
const FAINT: RGB = [190, 190, 186];
const LINE: RGB = [229, 229, 227];
const ROW_BG: RGB = [250, 250, 250];
const PILL: RGB = [242, 240, 235];
const GOLD: RGB = [218, 180, 90];
const GOLD_TEXT: RGB = [196, 150, 52];
const GREEN: RGB = [27, 122, 70];
const RED: RGB = [160, 46, 66];

const PAGE_W = 210;
const PAGE_H = 297;
const M = 15; // margin
const W = PAGE_W - 2 * M;

function hexToRgb(hex: string | null): RGB | null {
	const m = hex?.match(/^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
	return m ? [parseInt(m[1], 16), parseInt(m[2], 16), parseInt(m[3], 16)] : null;
}

/** One PDF with every sheet, each on a page of its own */
/** `logo` is the PNG of the Pool TV badge; without it a plain gold ring stands in */
export function renderSheets(models: SheetModel[], JsPDFClass: typeof JsPDF, title: string, logo?: Uint8Array): JsPDF {
	const doc = new JsPDFClass({ unit: 'mm', format: 'a4' });
	doc.setProperties({ title });
	doc.setLineHeightFactor(1);
	models.forEach((model, i) => {
		if (i) doc.addPage();
		drawSheet(doc, model, logo);
	});
	return doc;
}

function drawSheet(doc: JsPDF, model: SheetModel, logo?: Uint8Array) {

	const color = (c: RGB) => doc.setTextColor(c[0], c[1], c[2]);
	const fill = (c: RGB) => doc.setFillColor(c[0], c[1], c[2]);
	const stroke = (c: RGB) => doc.setDrawColor(c[0], c[1], c[2]);
	const font = (size: number, style: 'normal' | 'bold' = 'normal') => {
		doc.setFont('helvetica', style);
		doc.setFontSize(size);
	};
	/** Cuts text to fit a width, with "..." */
	const fit = (text: string, max: number) => {
		if (doc.getTextWidth(text) <= max) return text;
		let s = text;
		while (s.length > 1 && doc.getTextWidth(`${s}...`) > max) s = s.slice(0, -1);
		return `${s.trimEnd()}...`;
	};
	const text = (s: string, x: number, y: number, opts: { align?: 'left' | 'center' | 'right'; max?: number } = {}) =>
		doc.text(opts.max ? fit(s, opts.max) : s, x, y, { align: opts.align ?? 'left', baseline: 'middle' });
	const dot = (x: number, y: number, c: string | null, r = 1.4) => {
		const rgb = hexToRgb(c);
		if (!rgb) return 0;
		fill(rgb);
		doc.circle(x, y, r, 'F');
		return r * 2 + 1.8;
	};
	const sideColor = (side: SheetSide, winner: SheetSide | null) => (!winner ? INK : winner === side ? GREEN : RED);

	// ── Header: mark, title, date ───────────────────────────────────────────
	let y = M + 2;
	const logoR = 5.2;
	const lx = M + logoR;
	const ly = y + logoR;
	if (logo) {
		doc.addImage(logo, 'PNG', M, y, logoR * 2, logoR * 2, 'pool-tv-logo');
	} else {
		fill([10, 10, 10]);
		stroke(GOLD);
		doc.setLineWidth(0.7);
		doc.circle(lx, ly, logoR, 'FD');
	}

	font(17);
	color(INK);
	text(model.title, M + logoR * 2 + 4, ly - 2.2);
	font(9);
	color(GOLD_TEXT);
	text(model.subtitle, M + logoR * 2 + 4, ly + 3.9, { max: W - 70 });
	font(8.5);
	color(MUTED);
	text(model.date, M + W, ly, { align: 'right' });

	y = ly + logoR + 3;
	fill(GOLD);
	doc.rect(M, y, W, 0.9, 'F');

	// ── Score line ──────────────────────────────────────────────────────────
	y += 9;
	const half = W / 2 - 22;
	font(12.5);
	color(INK);
	const hx = M + 2;
	text(model.home.name, hx, y, { max: half - (hx - M) });
	const ax = M + W - 2;
	text(model.away.name, ax, y, { align: 'right', max: half - (M + W - ax) });

	const cx = M + W / 2;
	font(26, 'bold');
	color(sideColor('home', model.winner));
	text(String(model.home.score), cx - 5, y, { align: 'right' });
	color(sideColor('away', model.winner));
	text(String(model.away.score), cx + 5, y, { align: 'left' });
	fill(FAINT);
	doc.rect(cx - 2.2, y - 0.35, 4.4, 0.7, 'F');

	if (model.result) {
		y += 8;
		font(10);
		color(model.winner ? GREEN : MUTED);
		text(model.result, cx, y, { align: 'center' });
	}
	y += 6;

	const ensure = (h: number) => {
		if (y + h <= PAGE_H - M) return;
		doc.addPage();
		y = M;
	};

	// ── Rosters: players with wins and losses ───────────────────────────────
	if (model.rosters) {
		const gap = 4;
		const bw = (W - gap) / 2;
		const rowH = 4.6;
		const rows = Math.max(model.rosters.home.length, model.rosters.away.length, 1);
		const bh = 10 + rows * rowH + 3;
		ensure(bh);
		(['home', 'away'] as const).forEach((side, i) => {
			const bx = M + i * (bw + gap);
			stroke(LINE);
			doc.setLineWidth(0.3);
			doc.roundedRect(bx, y, bw, bh, 2, 2, 'S');
			font(9.5, 'bold');
			color(INK);
			const tx = bx + 4;
			text(model[side].name, tx, y + 5, { max: bw - (tx - bx) - 4 });
			stroke(LINE);
			doc.line(bx + 3, y + 8.5, bx + bw - 3, y + 8.5);

			model.rosters![side].forEach((p, j) => {
				const ry = y + 11 + j * rowH + rowH / 2 - 0.6;
				if (j) {
					stroke([240, 240, 238]);
					doc.line(bx + 3, ry - rowH / 2, bx + bw - 3, ry - rowH / 2);
				}
				font(7);
				color(FAINT);
				text(p.n, bx + 4.5, ry);
				font(9);
				color(p.sub ? MUTED : INK);
				text(p.name, bx + 11, ry, { max: bw - 34 });
				// "1V | 2D", right aligned
				const lost = `${p.lost}${model.labels.lost}`;
				const won = `${p.won}${model.labels.won}`;
				const right = bx + bw - 4;
				font(9);
				const lw = doc.getTextWidth(lost);
				color(RED);
				text(lost, right, ry, { align: 'right' });
				stroke(LINE);
				doc.line(right - lw - 1.6, ry - 1.4, right - lw - 1.6, ry + 1.4);
				color(GREEN);
				text(won, right - lw - 3.2, ry, { align: 'right' });
			});
		});
		y += bh + 3;
	}

	// ── Blocks of games ─────────────────────────────────────────────────────
	const rowH = 5.8;
	for (const block of model.blocks) {
		const played = block.rows.some((r) => r.score);
		const bh = 9 + block.rows.length * (rowH + 0.9) + 2;
		ensure(bh);
		stroke(LINE);
		doc.setLineWidth(0.3);
		doc.roundedRect(M, y, W, bh, 2, 2, 'S');
		font(9.5, 'bold');
		color(played ? INK : MUTED);
		text(block.title, cx, y + 4.4, { align: 'center' });
		doc.line(M + 3, y + 7.6, M + W - 3, y + 7.6);

		block.rows.forEach((r, j) => {
			const ry = y + 9 + j * (rowH + 0.9);
			const mid = ry + rowH / 2;
			fill(ROW_BG);
			stroke(LINE);
			doc.roundedRect(M + 3, ry, W - 6, rowH, 1.2, 1.2, 'FD');
			fill(PILL);
			doc.roundedRect(cx - 9, ry + 0.8, 18, rowH - 1.6, 1.2, 1.2, 'F');

			font(7);
			color(FAINT);
			text(r.n, M + 6.5, mid);
			const nameMax = W / 2 - 24;
			font(9.5);
			color(r.score ? sideColor('home', r.winner) : INK);
			text(r.home, M + 11, mid, { max: nameMax });
			font(9.5);
			color(r.score ? sideColor('away', r.winner) : INK);
			text(r.away, M + W - 6, mid, { align: 'right', max: nameMax });
			if (r.score) {
				font(8.5);
				color(INK);
				text(r.score, cx, mid, { align: 'center' });
			}
		});
		y += bh + 3;
	}
}
