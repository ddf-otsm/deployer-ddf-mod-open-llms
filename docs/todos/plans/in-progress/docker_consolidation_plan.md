# Docker Consolidation Plan
**Completion: 25%** | **Last Updated: 2025-05-26** | **Next Review: 2025-06-02**

## Overview
Consolidate duplicate Docker configurations to follow Blueprint v2.1 "zero root clutter" principle and establish single source of truth for Docker deployments.

## Problem Statement
Current repository has Docker configuration duplication:
- **Root Level**: `docker-compose.yml` (generated, Node.js focused), `Dockerfile` (Node.js production)
- **`docker/` Directory**: `docker-compose.yml` (Python focused), `Dockerfile` (Python), `Dockerfile.prod`, `requirements.txt`

This violates Blueprint v2.1 principles and creates confusion about which Docker setup to use.

## Success Criteria
- [ ] Single source of truth for Docker configurations in `config/docker/`
- [ ] Root level Docker files removed (following "zero root clutter")
- [ ] Platform-specific Docker configs generated from YAML templates
- [ ] Both Node.js and Python deployment paths supported
- [ ] Documentation updated with clear Docker usage instructions
- [ ] All Docker commands work through `workflow_tasks/run.sh`

## Risk Assessment
| Risk (Level) | Description | Mitigation |
|--------------|-------------|------------|
| High | Breaking existing Docker workflows | Test all Docker commands before/after consolidation |
| Med | Loss of Python-specific configurations | Preserve Python configs in new structure |
| Med | Generated files overwriting manual changes | Clear documentation on generated vs manual files |
| Low | Team confusion during transition | Clear migration guide and communication |

## Quality Gates / Timeline
| Milestone | Target Date | Gate Criteria |
|-----------|------------|---------------|
| Audit Complete | 2025-05-28 | All Docker files catalogued and compared |
| New Structure | 2025-06-02 | `config/docker/` structure implemented |
| Migration | 2025-06-09 | All configs moved, root files removed |
| Testing | 2025-06-16 | All Docker workflows tested and documented |
| Documentation | 2025-06-23 | Complete Docker usage guide published |

## Implementation Plan

### Phase 1: Audit and Analysis ✅ COMPLETED
- [x] Identify all Docker-related files
- [x] Compare configurations between root and `docker/` directory
- [x] Document differences and purposes

**Findings**:
- Root `docker-compose.yml`: Generated file, Node.js/TypeScript focused
- Root `Dockerfile`: Node.js production build with security hardening
- `docker/docker-compose.yml`: Python focused, includes monitoring stack
- `docker/Dockerfile`: Python-based with Flask/auth middleware
- `docker/Dockerfile.prod`: Production Python variant

### Phase 2: Design New Structure 🔄 IN-PROGRESS (50%)
- [x] Create `config/docker/` directory structure
- [x] Design platform-specific configuration templates
- [ ] Create Docker file generation scripts
- [ ] Design unified docker-compose template system

**New Structure**:
```
config/
├── docker/
│   ├── Dockerfile.node          # Node.js/TypeScript builds
│   ├── Dockerfile.python        # Python builds  
│   ├── compose-templates/       # Docker compose templates
│   │   ├── development.yml
│   │   ├── production.yml
│   │   └── monitoring.yml
│   └── scripts/
│       ├── generate-compose.sh
│       └── build-images.sh
└── platform-env/
    └── docker/
        ├── dev.yml              # ✅ COMPLETED
        ├── stg.yml
        ├── hmg.yml
        └── prd.yml
```

### Phase 3: Migration and Consolidation
- [ ] Move and consolidate Dockerfiles to `config/docker/`
- [ ] Create generation scripts for docker-compose files
- [ ] Update `workflow_tasks/run.sh` Docker platform adapter
- [ ] Remove root-level Docker files
- [ ] Update all references and imports

### Phase 4: Testing and Validation
- [ ] Test Node.js Docker workflow: `./run.sh --full -p docker -e dev`
- [ ] Test Python Docker workflow (if still needed)
- [ ] Validate all environment configurations (dev/stg/hmg/prd)
- [ ] Run smoke tests on generated configurations

### Phase 5: Documentation
- [ ] Update README.md with Docker usage instructions
- [ ] Create Docker deployment guide in `docs/deploy/`
- [ ] Document configuration generation process
- [ ] Add troubleshooting guide for common Docker issues

## Current Progress

### Files Analyzed
- `docker-compose.yml` (87 lines) - Generated Node.js config
- `Dockerfile` (73 lines) - Node.js production build
- `docker/docker-compose.yml` (128 lines) - Python + monitoring stack
- `docker/Dockerfile` (60 lines) - Python Flask application
- `docker/Dockerfile.prod` (75 lines) - Python production variant
- `docker/requirements.txt` (44 lines) - Python dependencies

### Key Decisions Made
1. **Primary Focus**: Node.js/TypeScript workflow (current main application)
2. **Python Support**: Preserve as optional deployment method
3. **Generation Strategy**: YAML configs → generated docker-compose files
4. **Platform Integration**: Full integration with `workflow_tasks/run.sh`

## Next Actions
1. Create consolidated Dockerfiles in `config/docker/`
2. Implement docker-compose generation from YAML templates
3. Update Docker platform adapter in `workflow_tasks/platform/docker.sh`
4. Test complete Docker workflow end-to-end
5. Remove duplicate files from root and `docker/` directory

## Related Files & Summaries
- `config/platform-env/docker/dev.yml` - Docker development configuration (96 lines)
- `workflow_tasks/platform/docker.sh` - Docker platform adapter (needs update)
- `workflow_tasks/run.sh` - Main execution script with Docker support
- Root `docker-compose.yml` and `Dockerfile` - To be removed after migration
- `docker/` directory contents - To be consolidated and moved

## Dependencies
- Blueprint v2.1 compliance requirements
- `workflow_tasks/run.sh` Docker platform support
- Existing application deployment workflows
- Team Docker usage patterns and preferences 