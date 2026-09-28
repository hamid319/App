export class PipelineError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly retryable = false,
    public readonly retryAfterSeconds?: number,
  ) {
    super(message);
    this.name = "PipelineError";
  }
}

export function asPipelineError(error: unknown): PipelineError {
  if (error instanceof PipelineError) return error;
  const message = error instanceof Error ? error.message : "Unknown failure";
  return new PipelineError("internal", message, false);
}
