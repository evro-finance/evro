import { LinkTextButton } from "@/src/comps/LinkTextButton/LinkTextButton";
import content from "@/src/content";
import { css } from "@/styled-system/css";
import { IconExternal } from "@liquity2/uikit";
import { a, useInView, useTransition } from "@react-spring/web";
import { memo } from "react";

const { title, subtitle, infoItems, learnMore } = content.redemptionInfo;

const iconComponents = {
	evro: BoldIcon,
	redemption: RedemptionIcon,
	interest: InterestIcon,
} as const;

export const RedemptionInfo = memo(function RedemptionInfo() {
	const [ref, inView] = useInView({ once: true });

	const iconsTrail = useTransition(
		infoItems.map((item) => ({ ...item, inView })),
		{
			keys: ({ text, inView }) => `${text}-${inView}`,
			from: {
				opacity: 0,
				transform: `
          scale3d(0.2, 0.2, 1)
          rotate3d(0, 0, 1, -180deg)
        `,
			},
			enter: {
				opacity: 1,
				transform: `
          scale3d(1, 1, 1)
          rotate3d(0, 0, 1, 0deg)
        `,
			},
			trail: 100,
			delay: 50,
			config: {
				mass: 1,
				tension: 800,
				friction: 60,
			},
		},
	);

	return (
		<section
			className={css({
				display: "flex",
				flexDirection: "column",
				gap: 16,
				padding: 16,
				color: "content",
				background: "fieldSurface",
				border: "1px solid token(colors.border)",
				borderRadius: 0,
				medium: {
					gap: 32,
				},
			})}
		>
			<header
				className={css({
					display: "flex",
					flexDirection: "column",
					fontSize: 16,
					gap: {
						base: 8,
						medium: 0,
					},
				})}
			>
				<h1
					className={css({
						fontWeight: 600,
					})}
				>
					{title}
				</h1>
				<p
					className={css({
						fontSize: 15,
						color: "contentAlt",
					})}
				>
					{subtitle}
				</p>
			</header>

			<ul
				ref={ref}
				className={css({
					display: "grid",
					gridTemplateColumns: "none",
					gap: 16,
					fontSize: 15,
					medium: {
						gridTemplateColumns: "repeat(3, 1fr)",
						gap: 24,
						fontSize: 14,
					},
				})}
			>
				{iconsTrail((props, item, _, index) => {
					const Icon = iconComponents[item.icon];
					return (
						<li
							key={index}
							className={css({
								display: "flex",
								gap: 12,
								flexDirection: "row",
								alignItems: "flex-start",
								medium: {
									gap: 16,
									flexDirection: "column",
									alignItems: "flex-start",
								},
							})}
						>
							<div
								className={css({
									display: "flex",
									paddingTop: {
										base: 2,
										medium: 0,
									},
								})}
							>
								<a.div
									className={css({
										display: "grid",
										placeItems: "center",
										width: 28,
										height: 28,
										transformOrigin: "center",
									})}
									style={props}
								>
									<Icon />
								</a.div>
							</div>
							<div>{item.text}</div>
						</li>
					);
				})}
			</ul>

			<div>
				<LinkTextButton
					href={learnMore.href}
					rel="noopener noreferrer"
					target="_blank"
					label={
						<span
							className={css({
								display: "flex",
								alignItems: "center",
								gap: 4,
								color: "accent",
							})}
						>
							<span>
								{learnMore.text}
							</span>
							<IconExternal size={16} />
						</span>
					}
				/>
			</div>
		</section>
	);
});

function BoldIcon() {
	return (
		<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
			<rect width="24" height="24" rx="12" fill="url(#paint0_linear_513_2396)" />
			<path d="M6.5994 17.9559L6 5.2793L8.4532 6.09581L12.2215 5.37242L18.0267 5.36954L17.035 8.06409L8.4532 7.52576L8.99154 16.1391L18.0254 14.7975V17.9391L8.99154 17.4008L6.5994 17.9559ZM7.56386 13.0561L7.79652 10.1119L14.3749 10.7558L17.035 13.0561H7.56386Z" fill="#FDFEFD" />
			<defs>
				<linearGradient id="paint0_linear_513_2396" x1="12" y1="0" x2="12" y2="24" gradientUnits="userSpaceOnUse">
					<stop stopColor="#A182F6" />
					<stop offset="1" stopColor="#263B67" />
				</linearGradient>
			</defs>
		</svg>
	);
}

function RedemptionIcon() {
	return (
		<svg width="28" height="24" fill="none">
			<path
				fill="#63D77D"
				d={"M16 0A12 12 0 0 0 4 12H0l5.334 5.333L10.667 12h-4"
					+ "a9.327 9.327 0 0 1 9.334-9.333A9.327 9.327 0 0 1 25.334 12"
					+ "a9.326 9.326 0 0 1-14.747 7.6l-1.893 1.92"
					+ "A12.002 12.002 0 0 0 27.87 10.24 12 12 0 0 0 16 0Z"}
			/>
			<circle cx="16" cy="12" r="3" fill="#1C1D4F" />
		</svg>
	);
}

function InterestIcon() {
	return (
		<svg width="20" height="24" fill="none">
			<path
				fill="#63D77D"
				d={"M10 0 0 4.364v6.545C0 16.964 4.267 22.625 10 24"
					+ "c5.733-1.375 10-7.036 10-13.09V4.363L10 0Z"}
			/>
			<circle cx="6" cy="9" r="2" fill="#1C1D4F" />
			<circle cx="14" cy="15" r="2" fill="#1C1D4F" />
			<path
				fill="#1C1D4F"
				d="m14.447 6.037 1.414 1.414-10.41 10.41-1.414-1.414z"
			/>
		</svg>
	);
}
