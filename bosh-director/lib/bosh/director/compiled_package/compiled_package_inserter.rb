require 'bosh/director/compiled_package'

module Bosh::Director::CompiledPackage
  class CompiledPackageInserter
    def initialize(blobstore_client)
      @blobstore_client = blobstore_client
    end

    def insert(compiled_package, release_version)
      package = Bosh::Director::Models::Package[fingerprint: compiled_package.package_fingerprint]
      raise ArgumentError, [compiled_package.inspect, release_version.inspect].inspect unless package

      stemcell = Bosh::Director::Models::Stemcell[sha1: compiled_package.stemcell_sha1]

      transitive_dependencies = release_version.transitive_dependencies(package)
      package_dependency_key = Bosh::Director::Models::CompiledPackage.create_dependency_key(transitive_dependencies)

      compiled_package_model = Bosh::Director::Models::CompiledPackage[
        package: package,
        stemcell: stemcell,
        dependency_key: package_dependency_key,
      ]

      return if compiled_package_model

      oid = File.open(compiled_package.blob_path) do |f|
        @blobstore_client.create(f)
      end

      begin
        Bosh::Director::Models::CompiledPackage.create(
          blobstore_id: oid,
          package: package,
          stemcell: stemcell,
          sha1: compiled_package.sha1,
          dependency_key: package_dependency_key,
          build: Bosh::Director::Models::CompiledPackage.generate_build_number(package, stemcell),
        )
      rescue
        @blobstore_client.delete(oid)
        raise
      end
    end
  end
end
