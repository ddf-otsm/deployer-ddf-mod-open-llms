# Documentation Taxonomy Plan
**Completion: 40%** | **Last Updated: 2025-05-27** | **Next Review: 2025-06-03**

## Overview
Establish a consistent, hierarchical documentation taxonomy for DeployerDDF Module Open Source LLM Models that follows industry best practices and supports both technical and non-technical users.

## Problem Statement
Current documentation lacks consistent structure and taxonomy:
- Mixed documentation styles and formats
- Unclear information hierarchy
- Difficult navigation and discovery
- Inconsistent naming conventions
- No clear ownership or maintenance guidelines

## Success Criteria
- [ ] Comprehensive documentation taxonomy defined and documented
- [ ] All existing documentation categorized and restructured
- [ ] Clear navigation hierarchy implemented
- [ ] Consistent naming conventions established
- [ ] Documentation ownership and maintenance guidelines created
- [ ] Search and discovery mechanisms improved
- [ ] Style guide and templates created for future documentation

## Risk Assessment
| Risk (Level) | Description | Mitigation |
|--------------|-------------|------------|
| High | Breaking existing documentation links during restructure | Implement redirect mapping and comprehensive link checking |
| High | Team resistance to new documentation standards | Involve team in taxonomy design and provide clear migration guide |
| Med | Information loss during restructuring | Create backup and audit trail of all changes |
| Med | Inconsistent adoption of new taxonomy | Implement automated validation and review processes |
| Low | Over-engineering the taxonomy structure | Keep taxonomy simple and practical, iterate based on usage |

## Quality Gates / Timeline
| Milestone | Target Date | Gate Criteria |
|-----------|------------|---------------|
| Taxonomy Design | 2025-06-02 | Complete taxonomy structure defined and approved |
| Pilot Implementation | 2025-06-09 | 25% of docs restructured using new taxonomy |
| Full Migration | 2025-06-16 | 100% of docs migrated to new structure |
| Validation & Testing | 2025-06-23 | All links working, navigation tested |
| Style Guide Complete | 2025-06-30 | Templates and guidelines published |

## Proposed Documentation Taxonomy

### Level 1: Primary Categories
```
docs/
├── 01-getting-started/     # Quick start, installation, first steps
├── 02-user-guides/         # End-user documentation
├── 03-developer-guides/    # Technical implementation guides
├── 04-api-reference/       # API documentation and references
├── 05-deployment/          # Deployment and operations guides
├── 06-architecture/        # System design and architecture docs
├── 07-contributing/        # Contribution guidelines and processes
├── 08-troubleshooting/     # Common issues and solutions
├── 09-reference/           # Configuration references, glossaries
└── 10-internal/            # Internal documentation and processes
```

### Level 2: Subcategories (Examples)

#### 01-getting-started/
- `README.md` - Project overview and quick start
- `installation.md` - Installation instructions
- `first-run.md` - First-time setup and configuration
- `basic-usage.md` - Basic usage examples

#### 02-user-guides/
- `llm-setup/` - Setting up and configuring LLM models
- `test-generation/` - Using AI for test generation
- `mutation-testing/` - Running mutation tests with StrykerJS
- `configuration/` - User configuration options
- `best-practices.md` - Best practices for AI testing

#### 03-developer-guides/
- `setup-development.md` - Development environment setup
- `coding-standards.md` - Code style and standards
- `testing.md` - Testing guidelines and frameworks
- `debugging.md` - Debugging techniques and tools
- `llm-integration.md` - Integrating with Ollama and other LLMs

#### 05-deployment/
- `platforms/` - Platform-specific deployment guides
  - `cursor.md` - Local development with Cursor IDE
  - `aws.md` - AWS CloudFormation deployment
  - `docker.md` - Docker containerized deployment
  - `replit.md` - Replit cloud deployment
- `environments/` - Environment-specific configurations
- `monitoring.md` - Monitoring and observability
- `security.md` - Security considerations for AI testing

## Implementation Plan

### Phase 1: Taxonomy Design and Validation ✅ COMPLETED (100%)
- [x] Research industry best practices for documentation taxonomy
- [x] Analyze current documentation structure and content
- [x] Design proposed taxonomy structure
- [x] Validate taxonomy with current project needs
- [x] Create migration mapping from old to new structure

### Phase 2: Infrastructure Setup
- [ ] Create new directory structure
- [ ] Implement navigation system (sidebar, breadcrumbs)
- [ ] Set up automated link checking
- [ ] Create documentation templates
- [ ] Establish style guide and writing standards

### Phase 3: Content Migration
- [ ] Migrate getting-started documentation
- [ ] Migrate user guides and tutorials
- [ ] Migrate developer documentation
- [ ] Migrate deployment and operations guides
- [ ] Migrate reference documentation

### Phase 4: Enhancement and Optimization
- [ ] Implement search functionality
- [ ] Add cross-references and related links
- [ ] Create documentation index and sitemap
- [ ] Optimize for different user personas
- [ ] Add feedback and improvement mechanisms

### Phase 5: Maintenance and Governance
- [ ] Establish documentation review process
- [ ] Create maintenance schedules and ownership
- [ ] Implement automated validation
- [ ] Train team on new documentation standards
- [ ] Create continuous improvement process

## Current Documentation Audit

### Existing Structure
```
docs/
├── deploy/              # Empty directory
├── guides/              # 17 files - mixed AWS, testing, migration guides
├── setup/               # Empty directory  
├── deployment/          # Unknown content
├── config/              # Unknown content
├── todos/               # Planning documents
├── index.md             # Main documentation index
├── SECURITY_*.md        # Security documentation (3 files)
├── CONFIG_*.md          # Configuration documentation (2 files)
└── FINAL_STATUS.md      # Status documentation
```

### Content Analysis
- **Total files**: ~25+ documentation files
- **Formats**: Primarily Markdown, some mixed with code
- **Quality**: Varies from comprehensive to minimal
- **Maintenance**: Inconsistent, some outdated content
- **Navigation**: Limited, relies on directory browsing
- **Key content areas**: AWS deployment, LLM testing, security, configuration

### Key Issues Identified
1. No clear entry point for new users
2. Mixed technical levels in same documents
3. Security and config docs scattered in root
4. Empty directories (deploy/, setup/)
5. No clear contribution guidelines
6. Limited troubleshooting resources
7. AWS-heavy content needs better organization

## Migration Mapping (Old → New Structure)

### Phase 1 Migration Map
```
Current Location → New Location

# Root level docs
docs/index.md → docs/01-getting-started/README.md
docs/SECURITY_*.md → docs/09-reference/security/
docs/CONFIG_*.md → docs/09-reference/configuration/
docs/FINAL_STATUS.md → docs/10-internal/status-reports/

# Guides directory reorganization  
docs/guides/guide.md → docs/02-user-guides/complete-guide.md
docs/guides/aws-*.md → docs/05-deployment/platforms/aws/
docs/guides/model-*.md → docs/02-user-guides/llm-setup/
docs/guides/secrets-management.md → docs/03-developer-guides/security/
docs/guides/run-script-blueprint.md → docs/03-developer-guides/
docs/guides/roadmap.md → docs/06-architecture/roadmap.md
docs/guides/cursor-chat-export-guide.md → docs/03-developer-guides/tools/

# Empty directories - populate with content
docs/deploy/ → docs/05-deployment/ (merge and enhance)
docs/setup/ → docs/01-getting-started/ (create setup guides)

# Internal planning
docs/todos/ → docs/10-internal/planning/
```

### Priority Migration Order
1. **High Priority**: Getting started, user guides, deployment
2. **Medium Priority**: Developer guides, architecture docs  
3. **Low Priority**: Internal docs, reference materials

## Naming Conventions

### File Naming
- Use lowercase with hyphens: `setup-development.md`
- Include action verbs where appropriate: `installing-dependencies.md`
- Be descriptive but concise: `docker-deployment-guide.md`
- Use consistent prefixes for related content: `api-authentication.md`, `api-endpoints.md`

### Directory Naming
- Use numbered prefixes for ordered content: `01-getting-started/`
- Use descriptive names: `troubleshooting/` not `issues/`
- Group related content: `platforms/` for platform-specific guides
- Avoid deep nesting (max 3 levels recommended)

### Content Structure
- Start with overview and objectives
- Use consistent heading hierarchy (H1 for title, H2 for main sections)
- Include prerequisites and assumptions
- Provide examples and code snippets
- End with next steps or related resources

## Templates and Standards

### Document Template Structure
```markdown
# Document Title
Brief description of what this document covers.

## Prerequisites
- List of requirements
- Assumed knowledge level

## Overview
High-level summary of the content.

## Main Content Sections
Detailed content with examples.

## Troubleshooting
Common issues and solutions.

## Next Steps
- Related documentation
- Further reading
```

### Style Guide Principles
1. **Clarity**: Write for your audience's technical level
2. **Consistency**: Use established patterns and terminology
3. **Completeness**: Include all necessary information
4. **Currency**: Keep content up-to-date
5. **Accessibility**: Consider different learning styles and abilities

## Success Metrics
- Documentation usage analytics (if available)
- User feedback and satisfaction scores
- Time to find information (user testing)
- Contribution rate to documentation
- Maintenance overhead reduction

## Next Actions
1. Complete taxonomy design and get stakeholder approval
2. Create new directory structure and navigation
3. Begin pilot migration with getting-started content
4. Develop templates and style guide
5. Plan full content migration schedule

## Related Files & Summaries
- Current `docs/` directory structure and content
- `README.md` - Main project entry point (needs restructuring)
- `workflow_tasks/run.sh` - Primary tool (needs better documentation)
- Platform-specific guides scattered across repository
- Configuration examples in `config/` directory

## Dependencies
- Blueprint v2.1 compliance requirements
- Team approval of new taxonomy structure
- Migration of existing content without breaking workflows
- Integration with development and deployment processes 