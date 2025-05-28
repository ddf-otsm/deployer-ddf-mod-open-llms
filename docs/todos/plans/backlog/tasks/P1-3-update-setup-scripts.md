# P1-3: Update Setup Scripts

**Priority**: P1 (Core Infrastructure)  
**Status**: Not Started  
**Assignee**: -  
**Due Date**: -  

## Description

Update setup scripts to use correct paths and improve reliability, error handling, and logging.

## Tasks

- [ ] Update `scripts/setup-secrets.sh` with correct paths:
  - [ ] Change references from `docker/` to `config/docker/`
  - [ ] Update references from `scripts/` to `tests/` for security check
- [ ] Add robust error handling
- [ ] Add detailed logging
- [ ] Ensure idempotence (can run multiple times safely)

## Acceptance Criteria

- [ ] All path references are correct
- [ ] Scripts handle errors gracefully
- [ ] Detailed logging shows progress and issues
- [ ] Scripts can be run multiple times without issues
- [ ] Scripts validate prerequisites before running
- [ ] Exit codes properly indicate success/failure

## Dependencies

- None (foundational infrastructure)

## Notes

The recent directory reorganization (Docker files moved to `config/docker/`, security check moved to `tests/`) requires updating setup scripts to use the new paths.

---

**Created**: May 27, 2025  
**Last Updated**: May 27, 2025 