"use client";

import type { TokenSymbol } from "@/src/types";

import { Amount } from "@/src/comps/Amount/Amount";
import { Logo } from "@/src/comps/Logo/Logo";
import { LinkTextButton } from "@/src/comps/LinkTextButton/LinkTextButton";
import { ACCOUNT_SCREEN } from "@/src/env";
import { useLiquityStats } from "@/src/liquity-utils";
import { useAccount } from "@/src/wagmi-utils";
import { css } from "@/styled-system/css";
import {
	HFlex,
	IconDiscord,
	IconExternal,
	IconX,
	shortenAddress,
	TokenIcon,
} from "@liquity2/uikit";
import { blo } from "blo";
import Image from "next/image";
import * as dn from "dnum";
import { WHITE_LABEL_CONFIG } from "@/src/white-label.config";

const DISPLAYED_PRICES = [WHITE_LABEL_CONFIG.tokens.mainToken.symbol] as const;

export function ProtocolStats() {
	const account = useAccount();
	const stats = useLiquityStats();

	const tvl = stats.data?.totalValueLocked;
	const maxSpApy = stats.data?.maxSpApy;

	return (
		<div
			className={css({
				display: "flex",
				width: "100%",
			})}
		>
			<div
				className={css({
					display: "flex",
					justifyContent: "space-between",
					width: "100%",
					height: 48,
					fontSize: 12,
					borderTop: "1px solid token(colors.tableBorder)",
					userSelect: "none",
				})}
			>
				<HFlex gap={16} alignItems='center'>
					<HFlex gap={4} alignItems='center'>
						<Logo size={16} />
						<span>TVL</span>{" "}
						<span>
							{stats.isLoading ? '…' :
								stats.error ? 'Error' :
									tvl ? (
										<Amount fallback='…' format='compact' prefix='€' value={tvl} />
									) : '…'}
						</span>
					</HFlex>
					<HFlex gap={4} alignItems='center'>
						<span>SP APR</span>{" "}
						<span>
							{maxSpApy ? (
								<Amount fallback='…' format='2z' suffix='%' value={dn.mul(maxSpApy, 100)} />
							) : (
								'…'
							)}
						</span>
					</HFlex>
				</HFlex>
				<HFlex gap={16}>
					{DISPLAYED_PRICES.map((symbol) => (
						<Price key={symbol} symbol={symbol} />
					))}
					<LinkTextButton
						href='https://discord.gg/evrofinance'
						external
						label={<IconDiscord size={16} />}
						className={css({
							display: "flex",
							alignItems: "center",
							color: "content",
							_hover: { opacity: 0.8 },
							_focusVisible: {
								outline: "2px solid token(colors.focused)",
							},
							_active: {
								translate: "0 1px",
							},
						})}
					/>
					<LinkTextButton
						href='https://x.com'
						external
						label={<IconX size={16} />}
						className={css({
							display: "flex",
							alignItems: "center",
							color: "content",
							_hover: { opacity: 0.8 },
							_focusVisible: {
								outline: "2px solid token(colors.focused)",
							},
							_active: {
								translate: "0 1px",
							},
						})}
					/>
					<LinkTextButton
						href='https://docs.evro.finance'
						external
						label={
							<HFlex gap={2}>
								<IconExternal size={16} />
								<span>Docs</span>
							</HFlex>
						}
						className={css({
							display: "flex",
							alignItems: "center",
							gap: "2",
							color: "content",
							_hover: { opacity: 0.8 },
							_focusVisible: {
								outline: "2px solid token(colors.focused)",
							},
							_active: {
								translate: "0 1px",
							},
						})}
					/>
					{account.address && ACCOUNT_SCREEN && (
						<LinkTextButton
							id='footer-account-button'
							href={`/account?address=${account.address}`}
							label={
								<HFlex gap={4} alignItems='center'>
									<Image
										alt=''
										width={16}
										height={16}
										src={blo(account.address)}
										className={css({
											borderRadius: "50%",
										})}
									/>
									{shortenAddress(account.address, 3)}
								</HFlex>
							}
							className={css({
								color: "content",
								borderRadius: 0,
								_focusVisible: {
									outline: "2px solid token(colors.focused)",
								},
								_active: {
									translate: "0 1px",
								},
							})}
						/>
					)}
				</HFlex>
			</div>
		</div>
	);
}

function Price({ symbol }: { symbol: TokenSymbol }) {
	const price = { data: 1 };
	return (
		<HFlex key={symbol} gap={4}>
			<TokenIcon size={16} symbol={symbol} />
			<HFlex gap={8}>
				<span>{symbol}</span>
				<Amount prefix='$' fallback='…' value={price.data} format='2z' />
			</HFlex>
		</HFlex>
	);
}