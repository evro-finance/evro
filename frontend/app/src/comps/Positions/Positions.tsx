import type { Address, BranchId, Position, PositionLoanUncommitted } from "@/src/types";
import type { ReactNode } from "react";

import { useBreakpointName } from "@/src/breakpoints";
import { ActionCard } from "@/src/comps/ActionCard/ActionCard";
import content from "@/src/content";
import { useWhiteLabelHeader } from "@/src/hooks/useWhiteLabel";
import { useEarnPositionsByAccount, useEarnPools, useLoansByAccount, useStakePosition } from "@/src/liquity-utils";
import { useSboldPosition } from "@/src/sbold";
import { css } from "@/styled-system/css";
import { a, useSpring, useTransition } from "@react-spring/web";
import { HFlex } from "@liquity2/uikit";
import * as dn from "dnum";
import { useEffect, useRef, useState } from "react";
import { match, P } from "ts-pattern";
import { NewPositionCard } from "./NewPositionCard";
import { PositionCard } from "./PositionCard";
import { PositionCardEarn } from "./PositionCardEarn";
import { PositionCardLoan } from "./PositionCardLoan";
import { PositionCardSbold } from "./PositionCardSbold";
import { PositionCardStake } from "./PositionCardStake";
import { SortButton, type SortField } from "./SortButton";

type Mode = "positions" | "loading" | "actions";

// Move actionCards inside component to make it dynamic

export function Positions({
	address,
	columns,
	showNewPositionCard = true,
	title = (mode) => (
		mode === "loading"
			? " "
			: mode === "positions"
				? content.home.myPositionsTitle
				: content.home.openPositionTitle
	),
}: {
	address: null | Address;
	columns?: number;
	showNewPositionCard?: boolean;
	title?: (mode: Mode) => ReactNode;
}) {
	const headerConfig = useWhiteLabelHeader();

	// Dynamic action cards based on configuration
	const actionCards = [
		...(headerConfig.navigation.showBorrow ? ["borrow" as const] : []),
		...(headerConfig.navigation.showEarn ? ["earn" as const] : []),
	];

	const loans = useLoansByAccount(address);
	const earnPositions = useEarnPositionsByAccount(address);
	const sboldPosition = useSboldPosition(address);
	// Only call useStakePosition if staking is enabled
	const stakePosition = useStakePosition(headerConfig.navigation.showStake ? address : null);

	const [sortBy, setSortBy] = useState<SortField>("default");

	const isPositionsPending = Boolean(
		address && (
			loans.isPending
			|| earnPositions.isPending
			|| sboldPosition.isPending
			|| (headerConfig.navigation.showStake && stakePosition.isPending)
		),
	);


	const hasStakePosition = stakePosition.data && dn.gt(stakePosition.data.deposit, 0);
	const hasSboldPosition = sboldPosition.data && dn.gt(sboldPosition.data.sbold, 0);

	const earnBranchIds = [...new Set(
		(earnPositions.data ?? [])
			.filter(p => p.type === "earn")
			.map(p => {
				if (p.type === "earn" && 'branchId' in p && p.branchId != null) {
					return p.branchId;
				}
				return null;
			})
			.filter((branchId): branchId is BranchId => branchId !== null)
	)];

	const poolsQuery = useEarnPools(earnBranchIds);
	const poolsData = poolsQuery.data || {};

	const positions = isPositionsPending ? [] : [
		...(loans.data ?? []),
		...(earnPositions.data ?? []),
		...(stakePosition.data && hasStakePosition && headerConfig.navigation.showStake ? [stakePosition.data] : []),
		...(sboldPosition.data && hasSboldPosition ? [sboldPosition.data] : []),
	];

	const positionsWithPoolData = positions.map(pos => {
		if (pos.type === "earn" && pos.branchId != null && poolsData[pos.branchId]) {
			return { ...pos, poolData: poolsData[pos.branchId] };
		}
		return pos;
	});

	const sortedPositions = [...positionsWithPoolData].sort((a, b) => {
		const getDeposit = (pos: any) => {
			if (pos.type === "earn" || pos.type === "stake" || pos.type === "sbold") {
				return Number(pos.deposit?.[0] ?? 0n);
			}
			if (pos.type === "borrow" || pos.type === "multiply") {
				return Number(pos.deposit?.[0] ?? 0n);
			}
			return 0;
		};

		const getDebt = (pos: any) => {
			if (pos.type === "borrow" || pos.type === "multiply") {
				return Number(pos.borrowed?.[0] ?? 0n);
			}
			return 0;
		};

		const getAvgRate = (pos: any) => {
			if ((pos.type === "borrow" || pos.type === "multiply") && pos.interestRate) {
				return Number(pos.interestRate[0] ?? 0n);
			}
			return 0;
		};

		const getAPR = (pos: any) => {
			if (pos.type === "earn" && pos.poolData?.apr?.[0] != null) {
				return Number(pos.poolData.apr[0]);
			}
			return 0;
		};

		const getAPR7d = (pos: any) => {
			if (pos.type === "earn" && pos.poolData?.apr7d?.[0] != null) {
				return Number(pos.poolData.apr7d[0]);
			}
			return 0;
		};

		const getPoolSize = (pos: any) => {
			if (pos.type === "earn" && pos.poolData?.totalDeposited?.[0] != null) {
				return Number(pos.poolData.totalDeposited[0]);
			}
			return 0;
		};

		switch (sortBy) {
			case "default":
				// For positions without branchId (like stake), put them at the end
				const aBranchId = 'branchId' in a ? Number(a.branchId) : 999;
				const bBranchId = 'branchId' in b ? Number(b.branchId) : 999;
				return aBranchId - bBranchId;
			case "apr-asc":
				return getAPR(a) - getAPR(b);
			case "apr-desc":
				return getAPR(b) - getAPR(a);
			case "apr7d-asc":
				return getAPR7d(a) - getAPR7d(b);
			case "apr7d-desc":
				return getAPR7d(b) - getAPR7d(a);
			case "poolSize-asc":
				return getPoolSize(a) - getPoolSize(b);
			case "poolSize-desc":
				return getPoolSize(b) - getPoolSize(a);
			case "avgRate-asc":
				return getAvgRate(a) - getAvgRate(b);
			case "avgRate-desc":
				return getAvgRate(b) - getAvgRate(a);
			case "deposited-asc":
				return getDeposit(a) - getDeposit(b);
			case "deposited-desc":
				return getDeposit(b) - getDeposit(a);
			case "debt-asc":
				return getDebt(a) - getDebt(b);
			case "debt-desc":
				return getDebt(b) - getDebt(a);
			default:
				return 0;
		}
	});

	let mode: Mode = address && sortedPositions && sortedPositions.length > 0
		? "positions"
		: isPositionsPending
			? "loading"
			: "actions";

	// preloading for 1 second, prevents flickering
	// since the account doesn’t reconnect instantly
	const [preLoading, setPreLoading] = useState(true);
	useEffect(() => {
		const timer = setTimeout(() => {
			setPreLoading(false);
		}, 500);
		return () => clearTimeout(timer);
	}, []);

	if (preLoading) {
		mode = "loading";
	}

	const breakpoint = useBreakpointName();

	return (
		<PositionsGroup
			columns={breakpoint === "small"
				? 1
				: breakpoint === "medium"
					? 2
					: columns}
			mode={mode}
			positions={sortedPositions ?? []}
			showNewPositionCard={showNewPositionCard}
			title={title}
			actionCards={actionCards}
			sortBy={sortBy}
			setSortBy={setSortBy}
		/>
	);
}

function PositionsGroup({
	columns,
	mode,
	positions,
	title,
	showNewPositionCard,
	actionCards,
	sortBy,
	setSortBy,
}: {
	columns?: number;
	mode: Mode;
	positions: Exclude<Position, PositionLoanUncommitted>[];
	title: (mode: Mode) => ReactNode;
	showNewPositionCard: boolean;
	actionCards: readonly ("borrow" | "earn")[];
	sortBy: SortField;
	setSortBy: (sortBy: SortField) => void;
}) {
	columns ??= (mode === "actions" || mode === "loading") ? actionCards.length : 3;

	const title_ = title(mode);

	const handleSortClick = (field: string) => {
		const currentField = sortBy.replace("-asc", "").replace("-desc", "");
		const isAsc = sortBy.endsWith("-asc");

		if (field === "default") {
			setSortBy("default");
		} else if (currentField === field) {
			setSortBy(`${field}-${isAsc ? "desc" : "asc"}` as SortField);
		} else {
			setSortBy(`${field}-desc` as SortField);
		}
	};

	const cards = match(mode)
		.returnType<Array<[number, ReactNode]>>()
		.with("positions", () => {
			let cards: Array<[number, ReactNode]> = [];

			if (showNewPositionCard) {
				cards.push([positions.length ?? -1, <NewPositionCard key="new" />]);
			}

			cards = cards.concat(
				positions.map((position, index) => (
					match(position)
						.returnType<[number, ReactNode]>()
						.with({ type: P.union("borrow", "multiply") }, (p) => [
							index,
							<PositionCardLoan key={index} {...p} />,
						])
						.with({ type: "earn" }, (p) => [
							index,
							<PositionCardEarn key={index} {...p} />,
						])
						.with({ type: "stake" }, (p) => [
							index,
							<PositionCardStake key={index} {...p} />,
						])
						.with({ type: "sbold" }, (p) => [
							index,
							<PositionCardSbold key={index} {...p} />,
						])
						.exhaustive()
				)) ?? [],
			);

			return cards;
		})
		.with("loading", () =>
			// Generate loading skeletons based on actionCards length
			Array.from({ length: actionCards.length }, (_, index) => [
				index,
				<PositionCard key={index} loading />
			])
		)
		.with("actions", () => (
			(showNewPositionCard ? actionCards : []).map((type, index) => [
				index,
				<ActionCard key={index} type={type} />,
			])
		))
		.exhaustive();

	const breakpoint = useBreakpointName();

	const cardHeight = mode === "actions" ? 144 : 180;
	const rows = Math.ceil(cards.length / columns);
	const containerHeight = cardHeight * rows + (breakpoint === "small" ? 16 : 24) * (rows - 1);

	const positionTransitions = useTransition(cards, {
		keys: ([index]) => `${mode}${index}`,
		from: {
			display: "none",
			opacity: 0,
			transform: "scale(0.9)",
		},
		enter: {
			display: "grid",
			opacity: 1,
			transform: "scale(1)",
		},
		leave: {
			display: "none",
			opacity: 0,
			transform: "scale(1)",
			immediate: true,
		},
		config: {
			mass: 1,
			tension: 1600,
			friction: 120,
		},
	});

	const animateHeight = useRef(false);
	if (mode === "loading") {
		animateHeight.current = true;
	}

	const containerSpring = useSpring({
		initial: { height: cardHeight },
		from: { height: cardHeight },
		to: { height: containerHeight },
		immediate: !animateHeight.current || mode === "loading",
		config: {
			mass: 1,
			tension: 2400,
			friction: 100,
		},
	});

	return (
		<div>
			{title_ && (
				<div className={css({
					display: "flex",
					justifyContent: "space-between",
					alignItems: "center",
					paddingBottom: {
						base: 16,
						medium: 20,
						large: 32,
					},
				})}>
					<h1
						className={css({
							fontSize: {
								base: 24,
								medium: 26,
								large: 32,
							},
							fontFamily: "var(--font-lexend-zetta, Lexend Zetta), sans-serif",
							letterSpacing: -7,
							fontWeight: 700,
							color: "content",
							userSelect: "none",
						})}
					>
						{title_}
					</h1>
					{positions.length > 0 && (() => {
						const hasEarnPositions = positions.some(p => p.type === "earn");
						const hasLoanPositions = positions.some(p => p.type === "borrow" || p.type === "multiply");
						const hasDepositPositions = positions.some(p => p.type === "earn" || p.type === "stake" || p.type === "sbold");

						return (
							<HFlex gap={8} alignItems="center">
								<p className={css({
									fontSize: 14,
									color: "contentAlt",
								})}>Sort by:</p>
								<div className={css({
									display: "flex",
									gap: 4,
									flexWrap: "wrap",
								})}>
									<SortButton
										label="Default"
										isActive={sortBy === "default"}
										onClick={() => handleSortClick("default")}
									/>
									<SortButton
										label="APR"
										field="apr"
										sortBy={sortBy}
										disabled={!hasEarnPositions}
										disabledTooltip={!hasEarnPositions ? "APR sorting is only available when you have earn positions" : undefined}
										onClick={() => handleSortClick("apr")}
									/>
									<SortButton
										label="7d APR"
										field="apr7d"
										sortBy={sortBy}
										disabled={!hasEarnPositions}
										disabledTooltip={!hasEarnPositions ? "7d APR sorting is only available when you have earn positions" : undefined}
										onClick={() => handleSortClick("apr7d")}
									/>
									<SortButton
										label="Pool size"
										field="poolSize"
										sortBy={sortBy}
										disabled={!hasEarnPositions}
										disabledTooltip={!hasEarnPositions ? "Pool size sorting is only available when you have earn positions" : undefined}
										onClick={() => handleSortClick("poolSize")}
									/>
									<SortButton
										label="Avg rate, p.a."
										field="avgRate"
										sortBy={sortBy}
										disabled={!hasLoanPositions}
										disabledTooltip={!hasLoanPositions ? "Average rate sorting is only available when you have loan positions" : undefined}
										onClick={() => handleSortClick("avgRate")}
									/>
									<SortButton
										label="Debt"
										field="debt"
										sortBy={sortBy}
										disabled={!hasLoanPositions}
										disabledTooltip={!hasLoanPositions ? "Debt sorting is only available when you have loan positions" : undefined}
										onClick={() => handleSortClick("debt")}
									/>
									<SortButton
										label={hasLoanPositions ? "Deposited/Collateral" : "Deposited"}
										field="deposited"
										sortBy={sortBy}
										disabled={!hasDepositPositions}
										disabledTooltip={!hasDepositPositions ? "Deposit sorting is only available when you have positions with deposits" : undefined}
										onClick={() => handleSortClick("deposited")}
									/>
								</div>
							</HFlex>
						);
					})()}
				</div>
			)}
			<a.div
				className={css({
					position: "relative",
				})}
				style={{
					...containerSpring,
				}}
			>
				<a.div
					className={css({
						display: "grid",
						gap: {
							base: 16,
							medium: 24,
						},
					})}
					style={{
						gridTemplateColumns: `repeat(${columns}, 1fr)`,
						gridAutoRows: cardHeight,
					}}
				>
					{positionTransitions((style, [_, card]) => (
						<a.div
							className={css({
								display: "grid",
								height: "100%",
								willChange: "transform, opacity",
							})}
							style={style}
						>
							{card}
						</a.div>
					))}
				</a.div>
			</a.div>
		</div>
	);
}
