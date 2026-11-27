/*
  YouTube thumbnail in the look of the overlays: the dark frame with the header band
  (Pool TV badge, pooltv.me, club logo | tag, club name) and a rounded window where the
  camera would be, here a photo of the table or the warm dark background. The title sits
  in the window's bottom left, in condensed capitals, with the subtitle under it.
*/

export const WIDTH = 1280;
export const HEIGHT = 720;

export interface ThumbnailContent {
	title: string;
	subtitle: string;
	tag: string;
	clubName: string;
	live: boolean;
	/** Shown faded when there is no title yet */
	placeholder: string;
	liveLabel: string;
	locale: string;
}

export interface ThumbnailAssets {
	poolTv: CanvasImageSource | null;
	club: CanvasImageSource | null;
	background: CanvasImageSource | null;
}

const FRAME = '#0d0f0e';
const GOLD = '#f8c045';
const RED = '#a8281d';
const HEADER = 112;
const EDGE = 18;
const RADIUS = 26;

const CONDENSED = '"Barlow Condensed", "Arial Narrow", sans-serif';
const SANS = 'Inter, "Segoe UI", system-ui, sans-serif';

/** The fonts the canvas draws with; it cannot wait for them itself */
export function loadFonts() {
	return Promise.all(
		[`700 100px ${CONDENSED}`, `500 30px ${CONDENSED}`, `600 30px ${SANS}`, `700 18px ${SANS}`].map((f) =>
			document.fonts.load(f).catch(() => [])
		)
	);
}

/** An image ready for the canvas, or null; fetched as a blob so the canvas can still be exported */
export async function loadImage(src: string | null | undefined): Promise<HTMLImageElement | null> {
	if (!src) return null;
	try {
		const res = await fetch(src);
		if (!res.ok) return null;
		return await imageFromBlob(await res.blob());
	} catch {
		return null;
	}
}

export function imageFromBlob(blob: Blob): Promise<HTMLImageElement | null> {
	return new Promise((resolve) => {
		const url = URL.createObjectURL(blob);
		const img = new Image();
		img.onload = () => resolve(img);
		img.onerror = () => resolve(null);
		img.src = url;
	});
}

function size(img: CanvasImageSource) {
	const i = img as HTMLImageElement;
	return { w: i.naturalWidth || (i.width as number), h: i.naturalHeight || (i.height as number) };
}

function spacing(ctx: CanvasRenderingContext2D, px: number) {
	if ('letterSpacing' in ctx) ctx.letterSpacing = `${px}px`;
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
	ctx.beginPath();
	ctx.roundRect(x, y, w, h, r);
}

/** Text cut with an ellipsis to fit */
function fit(ctx: CanvasRenderingContext2D, text: string, max: number) {
	if (ctx.measureText(text).width <= max) return text;
	let s = text;
	while (s && ctx.measureText(s + '…').width > max) s = s.slice(0, -1);
	return s.trimEnd() + '…';
}

/* Title words: *between asterisks* is drawn in gold */
type Word = { text: string; gold: boolean };

function words(title: string): Word[] {
	return title.split('*').flatMap((part, i) =>
		part
			.split(/\s+/)
			.filter(Boolean)
			.map((text) => ({ text, gold: i % 2 === 1 }))
	);
}

function wrap(ctx: CanvasRenderingContext2D, list: Word[], max: number): Word[][] {
	const lines: Word[][] = [];
	const space = ctx.measureText(' ').width;
	let line: Word[] = [];
	let width = 0;
	for (const w of list) {
		const ww = ctx.measureText(w.text).width;
		if (line.length && width + space + ww > max) {
			lines.push(line);
			line = [];
			width = 0;
		}
		width += (line.length ? space : 0) + ww;
		line.push(w);
	}
	if (line.length) lines.push(line);
	return lines;
}

/** Plain text wrapped to at most `maxLines`, the last one cut with an ellipsis */
function wrapText(ctx: CanvasRenderingContext2D, text: string, max: number, maxLines: number) {
	const lines = wrap(ctx, words(text.replaceAll('*', '')), max).map((l) => l.map((w) => w.text).join(' '));
	if (lines.length <= maxLines) return lines;
	const kept = lines.slice(0, maxLines);
	kept[maxLines - 1] = fit(ctx, lines.slice(maxLines - 1).join(' '), max);
	return kept;
}

export function render(canvas: HTMLCanvasElement, c: ThumbnailContent, a: ThumbnailAssets) {
	canvas.width = WIDTH;
	canvas.height = HEIGHT;
	const ctx = canvas.getContext('2d')!;
	ctx.textBaseline = 'alphabetic';

	// The frame
	ctx.fillStyle = FRAME;
	ctx.fillRect(0, 0, WIDTH, HEIGHT);

	const win = { x: EDGE, y: HEADER, w: WIDTH - EDGE * 2, h: HEIGHT - HEADER - EDGE };
	drawWindow(ctx, win, a);
	drawHeader(ctx, c, a);
	if (c.live) drawLive(ctx, win, c.liveLabel);
	drawText(ctx, win, c);
}

function drawWindow(ctx: CanvasRenderingContext2D, win: { x: number; y: number; w: number; h: number }, a: ThumbnailAssets) {
	ctx.save();
	roundRect(ctx, win.x, win.y, win.w, win.h, RADIUS);
	ctx.clip();

	if (a.background) {
		// The photo covers the window, then darkens towards the text
		const { w, h } = size(a.background);
		const scale = Math.max(win.w / w, win.h / h);
		const dw = w * scale;
		const dh = h * scale;
		ctx.drawImage(a.background, win.x + (win.w - dw) / 2, win.y + (win.h - dh) / 2, dw, dh);

		const side = ctx.createLinearGradient(win.x, 0, win.x + win.w, 0);
		side.addColorStop(0, 'rgb(0 0 0 / 0.82)');
		side.addColorStop(0.55, 'rgb(0 0 0 / 0.5)');
		side.addColorStop(1, 'rgb(0 0 0 / 0.12)');
		ctx.fillStyle = side;
		ctx.fillRect(win.x, win.y, win.w, win.h);
		const bottom = ctx.createLinearGradient(0, win.y + win.h * 0.35, 0, win.y + win.h);
		bottom.addColorStop(0, 'rgb(0 0 0 / 0)');
		bottom.addColorStop(1, 'rgb(0 0 0 / 0.6)');
		ctx.fillStyle = bottom;
		ctx.fillRect(win.x, win.y, win.w, win.h);
	} else {
		// Black with a faint warm light from above, like a lamp over the table
		const lamp = ctx.createRadialGradient(win.x + win.w * 0.62, win.y - 40, 0, win.x + win.w * 0.62, win.y - 40, win.w * 0.8);
		lamp.addColorStop(0, '#3a311f');
		lamp.addColorStop(0.45, '#14120e');
		lamp.addColorStop(1, '#000');
		ctx.fillStyle = lamp;
		ctx.fillRect(win.x, win.y, win.w, win.h);

		// The badge, large and faint, on the right
		if (a.poolTv) {
			const s = 560;
			ctx.globalAlpha = 0.07;
			ctx.drawImage(a.poolTv, win.x + win.w - s * 0.78, win.y + (win.h - s) / 2 + 20, s, s);
			ctx.globalAlpha = 1;
		}
	}
	ctx.restore();

	// Edge of the window, as on air
	roundRect(ctx, win.x + 0.5, win.y + 0.5, win.w - 1, win.h - 1, RADIUS);
	ctx.strokeStyle = 'rgb(255 255 255 / 0.1)';
	ctx.lineWidth = 1;
	ctx.stroke();
}

function divider(ctx: CanvasRenderingContext2D, x: number) {
	ctx.fillStyle = 'rgb(255 255 255 / 0.16)';
	ctx.fillRect(x, HEADER / 2 - 22, 1, 44);
}

function drawHeader(ctx: CanvasRenderingContext2D, c: ThumbnailContent, a: ThumbnailAssets) {
	const mid = HEADER / 2;
	const gap = 20;
	let x = EDGE + 8;

	// Left: Pool TV badge, pooltv.me, club logo
	if (a.poolTv) {
		ctx.drawImage(a.poolTv, x, mid - 36, 72, 72);
		x += 72 + gap - 6;
		ctx.font = `600 22px ${SANS}`;
		spacing(ctx, 0.4);
		ctx.fillStyle = 'rgb(255 255 255 / 0.55)';
		ctx.textBaseline = 'middle';
		ctx.fillText('pooltv.me', x, mid + 1);
		x += ctx.measureText('pooltv.me').width + gap;
	}
	if (a.club) {
		if (a.poolTv) {
			divider(ctx, x);
			x += 1 + gap;
		}
		const { w, h } = size(a.club);
		const scale = Math.min(64 / h, 300 / w);
		ctx.drawImage(a.club, x, mid - (h * scale) / 2, w * scale, h * scale);
	}

	// Right: tag pill, club name
	let right = WIDTH - EDGE - 8;
	ctx.textBaseline = 'middle';
	if (c.clubName) {
		ctx.font = `500 30px ${CONDENSED}`;
		spacing(ctx, 1.8);
		ctx.fillStyle = 'rgb(255 255 255 / 0.6)';
		const name = fit(ctx, c.clubName.toLocaleUpperCase(c.locale), 380);
		ctx.textAlign = 'right';
		ctx.fillText(name, right, mid + 1);
		ctx.textAlign = 'left';
		right -= ctx.measureText(name).width + gap;
	}
	if (c.tag.trim()) {
		if (c.clubName) {
			divider(ctx, right);
			right -= gap;
		}
		ctx.font = `700 18px ${SANS}`;
		spacing(ctx, 2);
		const tag = fit(ctx, c.tag.trim().toLocaleUpperCase(c.locale), 320);
		const w = ctx.measureText(tag).width + 36;
		roundRect(ctx, right - w + 0.5, mid - 20 + 0.5, w - 1, 39, 20);
		ctx.strokeStyle = 'rgb(255 255 255 / 0.2)';
		ctx.stroke();
		ctx.fillStyle = GOLD;
		ctx.fillText(tag, right - w + 18, mid + 1);
	}
	spacing(ctx, 0);
	ctx.textBaseline = 'alphabetic';
}

function drawLive(ctx: CanvasRenderingContext2D, win: { x: number; y: number }, label: string) {
	ctx.font = `700 26px ${CONDENSED}`;
	spacing(ctx, 2.6);
	const text = label.toUpperCase();
	const w = ctx.measureText(text).width + 64;
	const x = win.x + 40;
	const y = win.y + 38;
	roundRect(ctx, x, y, w, 44, 22);
	ctx.fillStyle = RED;
	ctx.fill();
	ctx.beginPath();
	ctx.arc(x + 24, y + 22, 6, 0, Math.PI * 2);
	ctx.fillStyle = '#fff';
	ctx.fill();
	ctx.textBaseline = 'middle';
	ctx.fillText(text, x + 40, y + 23);
	ctx.textBaseline = 'alphabetic';
	spacing(ctx, 0);
}

function drawText(ctx: CanvasRenderingContext2D, win: { x: number; y: number; w: number; h: number }, c: ThumbnailContent) {
	const left = win.x + 64;
	const max = win.w * 0.8;
	let bottom = win.y + win.h - 56;
	const empty = !c.title.trim();
	const title = (empty ? c.placeholder : c.title).toLocaleUpperCase(c.locale);

	// Subtitle, at the bottom
	ctx.font = `600 36px ${SANS}`;
	const sub = c.subtitle.trim() ? wrapText(ctx, c.subtitle.trim(), max, 2) : [];
	const subLine = 46;
	ctx.fillStyle = 'rgb(255 255 255 / 0.78)';
	ctx.shadowColor = 'rgb(0 0 0 / 0.5)';
	ctx.shadowBlur = 18;
	sub.forEach((line, i) => ctx.fillText(line, left, bottom - (sub.length - 1 - i) * subLine));
	if (sub.length) bottom -= (sub.length - 1) * subLine + 36 + 26;

	// Title: the largest size that fits in three lines and the room left above
	const room = bottom - (win.y + (c.live ? 130 : 70)) - 36;
	let fontSize = 172;
	let lines: Word[][] = [];
	for (; fontSize >= 64; fontSize -= 4) {
		ctx.font = `700 ${fontSize}px ${CONDENSED}`;
		spacing(ctx, fontSize * 0.005);
		lines = wrap(ctx, words(title), max);
		const tooWide = lines.some((l) => l.length === 1 && ctx.measureText(l[0].text).width > max);
		if (lines.length <= 3 && !tooWide && lines.length * fontSize * 0.92 <= room) break;
	}
	const lineHeight = fontSize * 0.92;
	const space = ctx.measureText(' ').width;
	ctx.globalAlpha = empty ? 0.3 : 1;
	ctx.shadowBlur = 28;
	lines.forEach((line, i) => {
		const y = bottom - (lines.length - 1 - i) * lineHeight;
		let x = left;
		for (const w of line) {
			ctx.fillStyle = w.gold ? GOLD : '#fff';
			ctx.fillText(w.text, x, y);
			x += ctx.measureText(w.text).width + space;
		}
	});
	ctx.globalAlpha = 1;
	ctx.shadowBlur = 0;
	ctx.shadowColor = 'transparent';
	spacing(ctx, 0);

	// The gold bar above the title
	const top = bottom - (lines.length - 1) * lineHeight - fontSize * 0.74;
	roundRect(ctx, left + 2, top - 34, 96, 8, 4);
	ctx.fillStyle = GOLD;
	ctx.fill();
}
