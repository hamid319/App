export type JobStatus =
  | "queued"
  | "running"
  | "ready"
  | "partial"
  | "empty"
  | "failed"
  | "paused";

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export interface CityIdentity {
  qid: string;
  name: string;
  countryQid: string;
  countryName: string;
  coordinates: Coordinates;
}

export interface AttractionCandidate {
  rank: number;
  qid: string;
  name: string;
  wikidataDescription?: string;
  coordinates: Coordinates;
  countryQid: string;
  types: string[];
  typeLabels: string[];
  sitelinks: number;
  distanceKm: number;
  p18Files: string[];
  sourceRevisionId: number;
  sourceRevisionTimestamp: string;
}

export interface CommonsPhotoCandidate {
  fileTitle: string;
  depictsQids: string[];
  origin: "p18" | "depicts";
}

export interface CommonsPhotoMetadata {
  fileTitle: string;
  pageId: number;
  sourceSha1: string;
  originalUrl: string;
  thumbnailUrl: string;
  mime: string;
  mediaType: string;
  width: number;
  height: number;
  revisionId: number;
  revisionTimestamp: string;
  creator: string;
  credit: string;
  licenseShortName: string;
  licenseUrl: string;
  description?: string;
  categories: string[];
}

export interface StoredPhoto {
  objectKey: string;
  publicUrl: string;
  commonsFileTitle: string;
  commonsFilePageUrl: string;
  commonsPageId: number;
  originalSourceUrl: string;
  creator: string;
  attribution: string;
  licenseName: string;
  licenseUrl: string;
  sourceRevisionId: number;
  sourceRevisionTimestamp: string;
  sourceSha1: string;
  outputSha256: string;
  width: number;
  height: number;
  mime: "image/webp";
  modifications: string;
  retrievedAt: string;
}

export interface PublishedPlace {
  id: string;
  source: "wikidata";
  sourceId: string;
  name: string;
  description: string;
  lat: number;
  lng: number;
  countryQid: string;
  cityQid: string;
  types: string[];
  photos: StoredPhoto[];
  sourceRevisionId: number;
  sourceRevisionTimestamp: string;
  retrievedAt: string;
}

export interface JobCounters {
  metadataRequests: number;
  thumbnailAttempts: number;
  downloadedBytes: number;
  activeRuntimeMs: number;
}

export interface JobCheckpoint {
  candidateIndex: number;
  acceptedPlaceIds: string[];
  counters: JobCounters;
  attempt: number;
  versionId: string;
}

export interface CityPreparationJob {
  id: string;
  cityQid: string;
  requestedBy: string;
  status: JobStatus;
  createdAt: Date;
  updatedAt: Date;
  checkpoint: JobCheckpoint;
  city?: CityIdentity;
  candidateCount?: number;
  qualifiedCount: number;
  failureCode?: string;
  publishedVersion?: string;
}

export interface AttemptClaim {
  job: CityPreparationJob;
  claimed: boolean;
}

export interface PublicVersion {
  city: CityIdentity;
  versionId: string;
  status: "ready" | "partial";
  places: PublishedPlace[];
  createdAt: Date;
  source: "wikidata-commons";
}

export interface PipelineLimits {
  candidateLimit: number;
  targetPlaces: number;
  targetPhotosPerPlace: number;
  metadataRequests: number;
  thumbnailAttempts: number;
  maxImageBytes: number;
  maxJobDownloadBytes: number;
  attemptRuntimeMs: number;
  maxAttempts: number;
  totalRuntimeMs: number;
  radiusKm: number;
  minSitelinks: number;
  minLongEdge: number;
  minShortEdge: number;
  maxOutputLongEdge: number;
}

export interface RequestContext {
  uid?: string;
  appCheckValid: boolean;
}

export interface RequestOutcome {
  kind: "fresh" | "pending" | "admitted";
  cityQid: string;
  jobId?: string;
  versionId?: string;
  status: JobStatus | "ready" | "partial";
}
