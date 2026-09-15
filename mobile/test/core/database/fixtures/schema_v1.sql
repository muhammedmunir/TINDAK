-- The exact M5a schema version 1, as created by the merged M5a code
-- (develop at 7c5fb27) and read back from sqlite_master.
--
-- Frozen. It exists so migration tests upgrade a real version 1 database —
-- the shape users' phones will actually have — rather than a version 2
-- database created fresh. Never edit it to match newer code.
CREATE TABLE "memories" ("id" TEXT NOT NULL, "content" TEXT NOT NULL, "intake_source" TEXT NOT NULL, "source_app" TEXT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "owner_user_id" TEXT NULL, "sync_status" TEXT NOT NULL, PRIMARY KEY ("id"), CHECK (sync_status IN ('local_only', 'pending', 'synced')), CHECK (intake_source IN ('share', 'paste')), CHECK (length(id) = 36), CHECK (owner_user_id IS NOT NULL OR sync_status = 'local_only'), CHECK (updated_at >= created_at), CHECK (length(content) <= 10000));
CREATE TABLE "memory_entities" ("id" TEXT NOT NULL, "memory_id" TEXT NOT NULL REFERENCES memories (id) ON DELETE CASCADE, "type" TEXT NOT NULL, "raw_value" TEXT NOT NULL, "normalized_value" TEXT NOT NULL, "search_value" TEXT NOT NULL, "confidence" REAL NOT NULL, "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"), CHECK (confidence >= 0 AND confidence <= 1), CHECK (start_offset >= 0 AND end_offset > start_offset));
CREATE INDEX memories_visible_created_idx ON memories (deleted_at, created_at);
CREATE INDEX memory_entities_memory_idx ON memory_entities (memory_id);
CREATE INDEX memory_entities_search_idx ON memory_entities (search_value);
PRAGMA user_version = 1;
