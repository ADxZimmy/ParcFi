/** USDC uses 6 decimals on its ERC-20 interface everywhere in ParcFi. */
export const USDC_DECIMALS = 6;

const SCALE = 10n ** BigInt(USDC_DECIMALS);

/** 7500000000n -> "7,500.00" */
export function formatUsdc(amount: bigint): string {
  const negative = amount < 0n;
  const abs = negative ? -amount : amount;
  const whole = abs / SCALE;
  const frac = abs % SCALE;
  const cents = (frac / 10_000n).toString().padStart(2, "0");
  const wholeStr = whole.toLocaleString("en-US");
  return `${negative ? "-" : ""}${wholeStr}.${cents}`;
}

/** "7500" | "7500.25" -> 7500000000n | 7500250000n. Throws on malformed input. */
export function parseUsdc(input: string): bigint {
  const trimmed = input.trim().replaceAll(",", "");
  if (!/^\d+(\.\d{0,6})?$/.test(trimmed)) {
    throw new Error(`Not a USDC amount: ${input}`);
  }
  const [whole = "0", frac = ""] = trimmed.split(".");
  const fracPadded = frac.padEnd(USDC_DECIMALS, "0");
  return BigInt(whole) * SCALE + BigInt(fracPadded);
}

export function shortAddress(address: string): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}
