"use client";

import type { CollateralSymbol } from "@/src/types";
import type { ReactNode } from "react";

import { useBreakpoint } from "@/src/breakpoints";
import { Amount } from "@/src/comps/Amount/Amount";
import { LinkTextButton } from "@/src/comps/LinkTextButton/LinkTextButton";
import { Positions } from "@/src/comps/Positions/Positions";
import content from "@/src/content";
import { WHITE_LABEL_CONFIG } from "@/src/white-label.config";
import { DNUM_1 } from "@/src/dnum-utils";
import {
	getBranch,
	getBranches,
	getCollToken,
	getToken,
	useAverageInterestRate,
	useBranchDebt,
	useEarnPool,
} from "@/src/liquity-utils";
import { getAvailableEarnPools } from "@/src/white-label.config";
import { useAccount } from "@/src/wagmi-utils";
import { css } from "@/styled-system/css";
import { IconBorrow, IconEarn, TokenIcon } from "@liquity2/uikit";
import * as dn from "dnum";
import { useState } from "react";
import { HomeTable } from "./HomeTable";

export function HomeScreen() {
	const account = useAccount();

	const [compact, setCompact] = useState(false);
	useBreakpoint(({ medium }) => {
		setCompact(!medium);
	});

	return (
		<div
			className={css({
				flexGrow: 1,
				display: "flex",
				flexDirection: "column",
				gap: {
					base: 40,
					medium: 40,
					large: 64,
				},
				width: "100%",
			})}
		>
			<Positions address={account.address ?? null} />
			<div
				className={css({
					display: "grid",
					gap: 24,
					gridTemplateColumns: {
						base: "1fr",
						large: "1fr 1fr",
					},
					gridTemplateAreas: {
						base: `
              "borrow"
              "earn"
              "yield"
            `,
						large: `
              "borrow earn"
              "borrow yield"
            `,
					},
				})}
			>
				<BorrowTable compact={compact} />
				<EarnTable compact={compact} />
			</div>
		</div>
	);
}

function BorrowTable({
	compact,
}: {
	compact: boolean;
}) {
	const columns: ReactNode[] = [
		"Collateral",
		<span
			key="avg-interest-rate"
			title="Average interest rate, per annum"
		>
			{compact ? "Rate" : "Avg rate, p.a."}
		</span>,
		<span
			key="max-ltv"
			title="Maximum Loan-to-Value ratio"
		>
			Max LTV
		</span>,
		<span
			key="total-debt"
			title="Total debt"
		>
			{compact ? "Debt" : "Total debt"}
		</span>,
	];

	if (!compact) {
		columns.push(null);
	}

	return (
		<div className={css({ gridArea: "borrow" })}>
			<HomeTable
				title={`Borrow ${WHITE_LABEL_CONFIG.tokens.mainToken.symbol} against wxDAI and assets`}
				subtitle="You can adjust your loans, including your interest rate, at any time"
				icon={<IconBorrow />}
				columns={columns}
				rows={getBranches().map(({ symbol }) => (
					<BorrowingRow key={symbol} compact={compact} symbol={symbol} />
				))}
			/>
		</div>
	);
}

function EarnTable({
	compact,
}: {
	compact: boolean;
}) {
	const columns: ReactNode[] = [
		"Pool",
		<abbr
			key="apr1d"
			title="Annual Percentage Rate over the last 24 hours"
		>
			APR
		</abbr>,
		<abbr
			key="apr7d"
			title="Annual Percentage Rate over the last 7 days"
		>
			7d APR
		</abbr>,
		"Pool size",
	];

	if (!compact) {
		columns.push(null);
	}

	return (
		<div
			className={css({
				gridArea: "earn",
			})}
		>
			<div
				className={css({
					position: "relative",
					zIndex: 2,
				})}
			>
				<HomeTable
					title={content.home.earnTable.title}
					subtitle={content.home.earnTable.subtitle}
					icon={<IconEarn />}
					columns={columns}
					rows={getAvailableEarnPools()
						.filter(pool => pool.type !== 'staked')
						.map((pool) => {
							const symbol = pool.symbol.toUpperCase();

							return (
								<EarnRewardsRow
									key={pool.symbol}
									compact={compact}
									symbol={symbol as CollateralSymbol}
								/>
							);
						})}
				/>
			</div>
		</div>
	);
}

function BorrowingRow({
	compact,
	symbol,
}: {
	compact: boolean;
	symbol: CollateralSymbol;
}) {
	const branch = getBranch(symbol);
	const collateral = getCollToken(branch.id);
	const avgInterestRate = useAverageInterestRate(branch.id);
	const branchDebt = useBranchDebt(branch.id);

	const maxLtv = collateral?.collateralRatio && dn.gt(collateral.collateralRatio, 0)
		? dn.div(DNUM_1, collateral.collateralRatio)
		: null;

	return (
		<tr>
			<td>
				<div
					className={css({
						display: "flex",
						alignItems: "center",
						gap: 8,
					})}
				>
					<TokenIcon symbol={symbol} size="mini" />
					<span>{collateral?.name}</span>
				</div>
			</td>
			<td>
				<Amount
					fallback="…"
					percentage
					value={avgInterestRate.data}
				/>
			</td>
			<td>
				<Amount
					value={maxLtv}
					percentage
				/>
			</td>
			<td>
				<Amount
					format="compact"
					prefix="€"
					fallback="…"
					value={branchDebt.data}
				/>
				{' / '}
				<Amount
					format="compact"
					prefix="€"
					fallback="…"
					value={Number(collateral?.maxDeposit)}
				/>
			</td>
			{!compact && (
				<td>
					<div
						className={css({
							display: "flex",
							gap: 16,
							justifyContent: "flex-end",
						})}
					>
						<LinkTextButton
							href={`/borrow/${symbol.toLowerCase()}`}
							label={
								<div
									className={css({
										display: "flex",
										alignItems: "center",
										gap: 4,
										fontSize: 14,
									})}
								>
									Borrow
									<TokenIcon symbol={WHITE_LABEL_CONFIG.tokens.mainToken.symbol} size="mini" />
								</div>
							}
							title={`Borrow ${collateral?.name} from ${symbol}`}
						/>
					</div>
				</td>
			)}
		</tr>
	);
}

function EarnRewardsRow({
	compact,
	symbol,
}: {
	compact: boolean;
	symbol: CollateralSymbol;
}) {
	const branch = getBranch(symbol);
	const token = getToken(symbol);
	const earnPool = useEarnPool(branch?.id ?? null);
	return (
		<tr>
			<td>
				<div
					className={css({
						display: "flex",
						alignItems: "center",
						gap: 8,
					})}
				>
					<TokenIcon symbol={symbol} size="mini" />
					<span>{token?.name}</span>
				</div>
			</td>
			<td>
				<Amount
					fallback="…"
					percentage
					value={earnPool.data?.apr}
				/>
			</td>
			<td>
				<Amount
					fallback="…"
					percentage
					value={earnPool.data?.apr7d}
				/>
			</td>
			<td>
				<Amount
					fallback="…"
					format="compact"
					prefix="€"
					value={earnPool.data?.totalDeposited}
				/>
			</td>
			{!compact && (
				<td>
					<LinkTextButton
						href={`/earn/${symbol.toLowerCase()}`}
						label={
							<div
								className={css({
									display: "flex",
									alignItems: "center",
									gap: 4,
									fontSize: 14,
								})}
							>
								Earn
								<TokenIcon.Group size="mini">
									<TokenIcon symbol={WHITE_LABEL_CONFIG.tokens.mainToken.symbol} />
									<TokenIcon symbol={symbol} />
								</TokenIcon.Group>
							</div>
						}
						title={`Earn ${WHITE_LABEL_CONFIG.tokens.mainToken.symbol} with ${token?.name}`}
					/>
				</td>
			)}
		</tr>
	);
}
