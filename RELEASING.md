# Releasing

A pushed tag builds the addon with the [BigWigs packager](https://github.com/BigWigsMods/packager) (GitHub Actions) and uploads it to CurseForge and as a GitHub release. The workflow is `.github/workflows/release.yml`; what goes into the zip is set in `.pkgmeta`.

## One-time setup

1. **GitHub repository** `ForeverDungeonJournalRoutes`, with this folder as its content. Also check `## X-Website` in the `.toc` and change it if the repository has another name.
2. **CurseForge project**: create it at <https://authors.curseforge.com> (game: World of Warcraft, license: MIT). Copy the numeric *Project ID* from the "About Project" box and add it to the `.toc`:

   ```
   ## X-Curse-Project-ID: 123456
   ```

3. **CurseForge API token**: <https://authors.curseforge.com/#/api-tokens>. Add it to the GitHub repository as the secret `CF_API_TOKEN` (Settings, Secrets and variables, Actions).
4. **GitHub Actions permissions**: Settings, Actions, General, Workflow permissions: "Read and write permissions".

## Releasing a version

1. Add the new version to the top of `CHANGELOG.md`.
2. Commit and push.
3. Tag and push the tag (annotated):

   ```
   git tag -a 0.1.0 -m "0.1.0"
   git push origin 0.1.0
   ```

A tag ending in `-alpha1` or `-beta1` (for example `0.2.0-beta1`) is uploaded as an alpha or beta release, any other tag as a release.

The packager recognizes interface `16001` as WoW Forever and uploads the file for that game version. The packaged addon gets the tag as its version (`## Version: @project-version@`).

## Trying the package locally

Run the packager without uploading: `release.sh -d` (needs bash, git, curl, zip; see the packager README). The result is in `.release/`.
