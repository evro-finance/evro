// All global styles should be imported here for easier maintenance
import "@liquity2/uikit/index.css";

import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import { BreakpointName } from "@/src/breakpoints";
import { About } from "@/src/comps/About/About";
import { AppLayout } from "@/src/comps/AppLayout/AppLayout";
import { Blocking } from "@/src/comps/Blocking/Blocking";
import content from "@/src/content";
import { VERCEL_ANALYTICS } from "@/src/env";
import { Ethereum } from "@/src/services/Ethereum";
import { IndicatorManager } from "@/src/services/IndicatorManager";
import { ReactQuery } from "@/src/services/ReactQuery";
import { StoredState } from "@/src/services/StoredState";
import { TransactionFlow } from "@/src/services/TransactionFlow";
import { SubgraphStatus } from "@/src/services/SubgraphStatus";
import { UiKit } from "@liquity2/uikit";
import { Analytics } from "@vercel/analytics/react";
import { Lexend_Zetta, Oswald } from "next/font/google";

const oswald = Oswald({
	variable: "--font-oswald",
	subsets: ["latin"],
});

const lexendZetta = Lexend_Zetta({
	variable: "--font-lexend-zetta",
	subsets: ["latin"],
});

export const metadata: Metadata = {
	title: content.appName,
	icons: "/favicon.svg",
};

export const viewport: Viewport = {
	width: "device-width",
	initialScale: 1,
	maximumScale: 1,
	userScalable: false,
};

export default function Layout({
	children,
}: {
	children: ReactNode;
}) {
	return (
		<html lang="en">
			<body className={`${oswald.variable} ${lexendZetta.variable} antialiased`}>
				<ReactQuery>
					<UiKit>
						<StoredState>
							<BreakpointName>
								<Ethereum>
									<IndicatorManager>
										<SubgraphStatus>
											<Blocking>
												<TransactionFlow>
													<About>
														<AppLayout>
															{children}
														</AppLayout>
													</About>
												</TransactionFlow>
											</Blocking>
										</SubgraphStatus>
									</IndicatorManager>
								</Ethereum>
							</BreakpointName>
						</StoredState>
					</UiKit>
				</ReactQuery>
				{VERCEL_ANALYTICS && <Analytics />}
			</body>
		</html>
	);
}
