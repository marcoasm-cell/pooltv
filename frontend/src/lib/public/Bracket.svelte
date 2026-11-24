<!--
  Tournament tree of one bracket (winners, losers or grand final): a column per round, fixtures
  spread so each sits level with the two it comes from, joined by lines.
-->
<script lang="ts">
	import { roundLabel } from '../format.ts';
	import type { Fixture } from '../types.ts';
	import FixtureBox from './FixtureBox.svelte';

	let { fixtures }: { fixtures: Fixture[] } = $props();

	// Height of one fixture's cell in the first round; later rounds get twice, four times…
	const CELL = 84;

	const columns = $derived.by(() => {
		const byRound = new Map<number, Fixture[]>();
		for (const f of fixtures) byRound.set(f.round, [...(byRound.get(f.round) ?? []), f]);
		return [...byRound.entries()].sort(([a], [b]) => a - b).map(([, fs]) => fs.sort((a, b) => a.position - b.position));
	});
	const tallest = $derived(Math.max(1, ...columns.map((c) => c.length)));
	// Two fixtures feed one in the next round: pair them; same count: a straight line
	const paired = (i: number) => i < columns.length - 1 && columns[i + 1].length * 2 === columns[i].length;
	const groups = (col: Fixture[], pair: boolean) =>
		pair ? Array.from({ length: col.length / 2 }, (_, k) => col.slice(k * 2, k * 2 + 2)) : col.map((f) => [f]);
</script>

<div class="-mx-4 overflow-x-auto px-4 pb-2">
	<div class="flex w-max gap-8">
		{#each columns as col, i (col[0].id)}
			<div class="flex w-56 flex-none flex-col">
				<h3 class="eyebrow mb-2 truncate border-b border-gray-200 pb-2">{roundLabel(col[0].round_label)}</h3>
				<div class="flex flex-col" style:height="{tallest * CELL}px">
					{#each groups(col, paired(i)) as group (group[0].id)}
						<div class="relative flex flex-1 flex-col" class:join={group.length === 2}>
							{#each group as f (f.id)}
								<div class="slot relative flex flex-1 items-center" class:out={i < columns.length - 1} class:in={i > 0}>
									<FixtureBox fixture={f} />
								</div>
							{/each}
						</div>
					{/each}
				</div>
			</div>
		{/each}
	</div>
</div>

<style>
	/* Lines between rounds: a stub out of each fixture, a bar joining a pair, a stub into the next */
	.slot.out::after,
	.slot.in::before {
		content: '';
		position: absolute;
		top: 50%;
		width: 1rem;
		border-top: 1.5px solid var(--color-gray-300);
	}
	.slot.out::after {
		right: -1rem;
	}
	.slot.in::before {
		left: -1rem;
	}
	.join::after {
		content: '';
		position: absolute;
		right: -1rem;
		top: 25%;
		bottom: 25%;
		border-right: 1.5px solid var(--color-gray-300);
	}
</style>
