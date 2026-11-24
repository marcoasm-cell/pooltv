<!-- QR code of a link, drawn as SVG (sharp at any size). Dark modules on a white quiet zone. -->
<script lang="ts">
	import qrcode from 'qrcode-generator';

	let { value, class: cls = '', label = '' }: { value: string; class?: string; label?: string } = $props();

	// One path of 1×1 squares; the 2-module margin is the quiet zone scanners need
	const MARGIN = 2;
	const qr = $derived.by(() => {
		const code = qrcode(0, 'M');
		code.addData(value);
		code.make();
		const n = code.getModuleCount();
		let d = '';
		for (let r = 0; r < n; r++)
			for (let c = 0; c < n; c++) if (code.isDark(r, c)) d += `M${c + MARGIN} ${r + MARGIN}h1v1h-1z`;
		return { size: n + MARGIN * 2, d };
	});
</script>

<svg viewBox="0 0 {qr.size} {qr.size}" class={cls} role="img" aria-label={label || value} shape-rendering="crispEdges">
	<rect width={qr.size} height={qr.size} fill="#fff" />
	<path d={qr.d} fill="#000" />
</svg>
