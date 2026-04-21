# frozen_string_literal: true

require "json"
require "rake/clean"

mod_license = "default_mit"
mod_category = "localizations"
mod_tags = %w[]

info = JSON.parse(File.read("info.json"))
mod_name = info["name"]
mod_version = info["version"]
dist_dir = "dist"
archive = "#{dist_dir}/#{mod_name}_#{mod_version}.zip"

CLOBBER.include(dist_dir)

desc "Build release zip"
task build: archive

archive_sources = %x[git archive --format=tar HEAD | tar -t -f -].lines(chomp: true)

directory dist_dir

file archive => [dist_dir, *archive_sources] do |t|
  prefix = File.basename(t.name, ".zip")
  sh "git archive --prefix #{prefix}/ HEAD -o #{t.name}"
end

desc "Install MOD locally"
task install: archive do |t|
  paths = JSON.parse(%x[bin/factorix path --json])
  cp t.prerequisites.first, paths["mod_dir"]
end

desc "Upload MOD to Factorio MOD Portal"
task release: archive do |t|
  abort "release task must be run from GitHub Actions" unless ENV["GITHUB_ACTIONS"]

  source_url = %x[git remote get-url origin].chomp

  sh("bin/factorix", "mod", "upload", t.prerequisites.first,
    "--category", mod_category,
    "--license", mod_license,
    "--source-url", source_url,
    "--description", File.read("README.md"))

  sh("bin/factorix", "mod", "edit", mod_name,
    "--summary", info["description"],
    "--tags", mod_tags.join(","))
end
