INSERT INTO deploy_bundles (
    app_id,
    version_tag,
    manifest_json,
    bundle_zip,
    sha256
)
VALUES (
    :app_id,
    :version_tag,
    :manifest_json,
    EMPTY_BLOB(),
    :sha256
)
RETURNING bundle_zip INTO :blob;
