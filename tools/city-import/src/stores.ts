// Where publish writes: Cloudflare R2 for photos, Firestore for data.
// Both behind small interfaces so publish can be tested with fakes.

import { HeadObjectCommand, ListObjectsV2Command, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import type { Firestore } from "firebase-admin/firestore";
import type { CityDoc, PlaceDoc } from "./model.js";

export interface StoredObjectInfo {
  width: number;
  height: number;
  sha256: string;
}

export interface PhotoStore {
  /** Info of an object uploaded by an earlier run, or null. */
  head(key: string): Promise<StoredObjectInfo | null>;
  put(key: string, bytes: Buffer, info: StoredObjectInfo, meta: Record<string, string>): Promise<void>;
  publicUrl(key: string): string;
}

export interface DataStore {
  /** Ids and status of the curated places already stored for a city. */
  existingPlaces(cityId: string): Promise<Map<string, PlaceDoc["status"]>>;
  writePlaces(places: PlaceDoc[]): Promise<void>;
  hidePlaces(ids: string[], importRunId: string): Promise<void>;
  writeCity(city: CityDoc): Promise<void>;
  writeRun(id: string, run: Record<string, unknown>): Promise<void>;
}

export interface R2Settings {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  publicBaseUrl: string;
}

export class R2PhotoStore implements PhotoStore {
  private readonly client: S3Client;

  constructor(private readonly settings: R2Settings) {
    this.client = new S3Client({
      region: "auto",
      endpoint: `https://${settings.accountId}.r2.cloudflarestorage.com`,
      credentials: { accessKeyId: settings.accessKeyId, secretAccessKey: settings.secretAccessKey },
    });
  }

  async head(key: string): Promise<StoredObjectInfo | null> {
    try {
      const response = await this.client.send(new HeadObjectCommand({ Bucket: this.settings.bucket, Key: key }));
      const meta = response.Metadata ?? {};
      if (!meta.sha256 || !meta.width || !meta.height) return null;
      return { sha256: meta.sha256, width: Number(meta.width), height: Number(meta.height) };
    } catch (error) {
      const status = (error as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
      if (status === 404) return null;
      throw error;
    }
  }

  async put(key: string, bytes: Buffer, info: StoredObjectInfo, meta: Record<string, string>): Promise<void> {
    await this.client.send(new PutObjectCommand({
      Bucket: this.settings.bucket,
      Key: key,
      Body: bytes,
      ContentType: "image/webp",
      CacheControl: "public, max-age=31536000, immutable",
      Metadata: { ...meta, sha256: info.sha256, width: String(info.width), height: String(info.height) },
    }));
  }

  /** Total size of all objects in the bucket (one list call per 1000 objects). */
  async totalBytes(): Promise<number> {
    let total = 0;
    let token: string | undefined;
    do {
      const page = await this.client.send(new ListObjectsV2Command({
        Bucket: this.settings.bucket,
        ContinuationToken: token,
      }));
      for (const object of page.Contents ?? []) total += object.Size ?? 0;
      token = page.IsTruncated ? page.NextContinuationToken : undefined;
    } while (token);
    return total;
  }

  publicUrl(key: string): string {
    return `${this.settings.publicBaseUrl.replace(/\/$/, "")}/${key.split("/").map(encodeURIComponent).join("/")}`;
  }
}

export class FirestoreDataStore implements DataStore {
  constructor(private readonly db: Firestore) {}

  async existingPlaces(cityId: string): Promise<Map<string, PlaceDoc["status"]>> {
    const snapshot = await this.db
      .collection("places")
      .where("cityId", "==", cityId)
      .where("source", "==", "wikidata")
      .select("status")
      .get();
    return new Map(snapshot.docs.map((doc) => [doc.id, (doc.get("status") as PlaceDoc["status"]) ?? "active"]));
  }

  async writePlaces(places: PlaceDoc[]): Promise<void> {
    for (let i = 0; i < places.length; i += 400) {
      const batch = this.db.batch();
      for (const place of places.slice(i, i + 400)) {
        batch.set(this.db.collection("places").doc(place.id), place);
      }
      await batch.commit();
    }
  }

  async hidePlaces(ids: string[], importRunId: string): Promise<void> {
    for (let i = 0; i < ids.length; i += 400) {
      const batch = this.db.batch();
      for (const id of ids.slice(i, i + 400)) {
        batch.update(this.db.collection("places").doc(id), {
          status: "hidden",
          importRunId,
          updatedAt: new Date().toISOString(),
        });
      }
      await batch.commit();
    }
  }

  async writeCity(city: CityDoc): Promise<void> {
    await this.db.collection("cities").doc(city.id).set(city);
  }

  async writeRun(id: string, run: Record<string, unknown>): Promise<void> {
    await this.db.collection("importRuns").doc(id).set(run, { merge: true });
  }
}
