# GitHub Repository Deprecation Steps

Follow these manual steps to deprecate the wrong repository (deployer-ddf-open-llms).

## Step 1: Update Repository README

1. Navigate to: https://github.com/ddf-otsm/deployer-ddf-open-llms
2. Click on the "Edit" button (pencil icon) for the README.md file
3. Replace the entire content with the template from:
   `docs/todos/plans/in-progress/deprecated-readme-template.md`
4. Commit the changes with message: "DEPRECATED: Repository moved to https://github.com/ddf-otsm/deployer-ddf-mod-open-llms"

## Step 2: Update Repository Description and Topics

1. Navigate to: https://github.com/ddf-otsm/deployer-ddf-open-llms/settings
2. Update the description to: "[DEPRECATED] This repository has been moved to https://github.com/ddf-otsm/deployer-ddf-mod-open-llms"
3. Add the topic "deprecated" to the repository

## Step 3: Rename the Repository

1. Navigate to: https://github.com/ddf-otsm/deployer-ddf-open-llms/settings
2. In the "Repository name" section, change the name to "deprec-deployer-ddf"
3. Type the repository name to confirm
4. Click "Rename"

## Step 4: Archive the Repository

1. Navigate to: https://github.com/ddf-otsm/deprec-deployer-ddf/settings
2. Scroll down to the "Danger Zone"
3. Click "Archive this repository"
4. Read the warning and confirm by typing the repository name
5. Click "I understand the consequences, archive this repository"

## Verification Checklist

- [ ] README updated with deprecation notice
- [ ] Repository description updated with [DEPRECATED] prefix
- [ ] Repository renamed to "deprec-deployer-ddf"
- [ ] Repository archived (made read-only)
- [ ] Documentation updated to reference new repository

---

*These steps require GitHub admin access to the repository.*
