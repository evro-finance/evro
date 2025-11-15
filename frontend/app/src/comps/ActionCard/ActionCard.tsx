import content from "@/src/content";
import { WHITE_LABEL_CONFIG } from "@/src/white-label.config";
import { css, cx } from "@/styled-system/css";
import { token } from "@/styled-system/tokens";
import { a, useSpring } from "@react-spring/web";
import Link from "next/link";
import { useState } from "react";
import { match } from "ts-pattern";
import { ActionIcon } from "./ActionIcon";

export function ActionCard({
	type,
}: {
	type: "borrow" | "multiply" | "earn" | "stake";
}) {
	const [hint, setHint] = useState(false);
	const [active, setActive] = useState(false);

	const hintSpring = useSpring({
		transform: active
			? "scale(1.01)"
			: hint
				? "scale(1.02)"
				: "scale(1)",
		boxShadow: hint && !active
			? "0 2px 4px rgba(0, 0, 0, 0.1)"
			: "0 2px 4px rgba(0, 0, 0, 0)",
		immediate: active,
		config: {
			mass: 1,
			tension: 1800,
			friction: 80,
		},
	});

	const { actions: ac } = content.home;
	const { description, path, title, colors } = match(type)
		.with("borrow", () => ({
			colors: {
				background: token(`colors.${WHITE_LABEL_CONFIG.brandColors.accent2}`),
				foreground: token(`colors.${WHITE_LABEL_CONFIG.brandColors.primaryContent}`),
				foregroundAlt: token(`colors.${WHITE_LABEL_CONFIG.brandColors.primaryContentAlt}`),
			},
			description: ac.borrow.description,
			path: "/borrow",
			title: ac.borrow.title,
		}))
		.with("multiply", () => ({
			colors: {
				background: token(`colors.${WHITE_LABEL_CONFIG.brandColors.accent2}`),
				foreground: token(`colors.${WHITE_LABEL_CONFIG.brandColors.accent2Content}`),
				foregroundAlt: token(`colors.${WHITE_LABEL_CONFIG.brandColors.accent2ContentAlt}`),
			},
			description: ac.multiply.description,
			path: "/multiply",
			title: ac.multiply.title,
		}))
		.with("earn", () => ({
			colors: {
				background: token(`colors.${WHITE_LABEL_CONFIG.brandColors.accent1}`),
				foreground: token(`colors.${WHITE_LABEL_CONFIG.brandColors.accent1Content}`),
				foregroundAlt: token(`colors.${WHITE_LABEL_CONFIG.brandColors.accent1ContentAlt}`),
			},
			description: ac.earn.description,
			path: "/earn",
			title: ac.earn.title,
		}))
		.with("stake", () => ({
			colors: {
				background: token(`colors.${WHITE_LABEL_CONFIG.brandColors.secondary}`),
				foreground: token(`colors.${WHITE_LABEL_CONFIG.brandColors.secondaryContent}`),
				foregroundAlt: token(`colors.${WHITE_LABEL_CONFIG.brandColors.secondaryContentAlt}`),
			},
			description: ac.stake.description,
			path: "/stake",
			title: ac.stake.title,
		}))
		.exhaustive();

	return (
		<Link
			key={path}
			href={path}
			onMouseEnter={() => setHint(true)}
			onMouseLeave={() => setHint(false)}
			onMouseDown={() => setActive(true)}
			onMouseUp={() => setActive(false)}
			onBlur={() => setActive(false)}
			className={cx(
				"group",
				css({
					display: "flex",
					color: "gray:50",
					outline: 0,
					userSelect: "none",
				}),
			)}
		>
			<a.section
				className={css({
					position: "relative",
					display: "flex",
					flexDirection: "column",
					gap: 16,
					width: "100%",
					padding: "20px 24px",
					_groupFocusVisible: {
						outline: "2px solid token(colors.focused)",
						outlineOffset: 2,
					},
					_groupHover: {
						transform: "scale(1.05)",
					},
				})}
				style={{
					background: colors.background,
					color: colors.foreground,
					...hintSpring,
				}}
			>
				<h1 className={css({
					fontSize: 20,
					fontFamily: "var(--font-lexend-zetta, Lexend Zetta), sans-serif",
					letterSpacing: -5,
					fontWeight: 700,
				})}>{title}</h1>
				<p
					className={css({
						height: 64,
						fontSize: 14,
					})}
					style={{
						color: colors.foregroundAlt,
					}}
				>
					{description}
				</p>
				<div
					className={css({
						position: "absolute",
						inset: "20px 24px auto auto",
					})}
				>
					<ActionIcon
						colors={colors}
						iconType={type}
						state={hint ? "active" : "idle"}
					/>
				</div>
			</a.section>
		</Link>
	);
}
