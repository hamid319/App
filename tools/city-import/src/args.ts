// Command-line arguments of cli.ts. Strict on purpose: a typo such as
// --city=pt_lisbon or --dryrun must stop the run, not publish every city for real.

export interface CliArgs {
  command: string | undefined;
  cityIds: string[];
  dryRun: boolean;
  port: number;
}

export function parseArgs(argv: string[]): CliArgs {
  const [command, ...rest] = argv;
  const result: CliArgs = { command, cityIds: [], dryRun: false, port: 4173 };
  for (let i = 0; i < rest.length; i += 1) {
    const arg = rest[i];
    if (arg === "--dry-run") {
      result.dryRun = true;
    } else if (arg === "--city") {
      result.cityIds = (rest[i + 1] ?? "").split(",").filter(Boolean);
      if (result.cityIds.length === 0 || rest[i + 1].startsWith("-")) throw new Error("--city needs one or more city ids");
      i += 1;
    } else if (arg === "--port") {
      result.port = Number(rest[i + 1]);
      if (!Number.isInteger(result.port) || result.port <= 0) throw new Error("--port needs a port number");
      i += 1;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return result;
}
