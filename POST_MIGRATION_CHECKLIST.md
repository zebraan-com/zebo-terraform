# Post-Migration Checklist

## ✅ zebo-terraform Repository

### GitHub Configuration
- [ ] Add repository secrets:
  - [ ] `GCP_CREDENTIALS`
  - [ ] `GCP_PROJECT_ID`
  - [ ] `ZEO_DB_PASSWORD`
  - [ ] `ZEO_OPENAI_KEY`
  - [ ] `ZEO_MF_UTIL_KEY`

- [ ] Add repository variables:
  - [ ] `TERRAFORM_SERVICE_ACCOUNT_EMAIL` (required)
  - [ ] `GCP_REGION` (optional, default: asia-south1)
  - [ ] `ARTIFACT_REGISTRY_ID` (optional, default: zebo-registry)
  - [ ] `NODE_MACHINE_TYPE` (optional, default: e2-medium)
  - [ ] `MIN_NODES` (optional, default: 1)
  - [ ] `MAX_NODES` (optional, default: 5)
  - [ ] `USE_SPOT_INSTANCES` (optional, default: true)
  - [ ] `GKE_DELETION_PROTECTION` (optional, default: true)

### Deployment
- [ ] Test workflow manually (Actions → Terraform Deployment → Run workflow)
- [ ] Verify infrastructure created successfully
- [ ] Check Terraform outputs
- [ ] Configure kubectl with the cluster

## ✅ zebo-infra Repository

### Cleanup (Optional)
- [ ] Update README to reflect Kubernetes-only purpose
- [ ] Remove `terraform/` directory (after confirming zebo-terraform works)
- [ ] Remove Terraform-related workflows
- [ ] Update documentation

### Documentation
- [ ] Update README with new repository structure
- [ ] Add link to zebo-terraform for infrastructure changes
- [ ] Document Kubernetes deployment process
- [ ] Document ArgoCD setup

## ✅ Team Communication

- [ ] Notify team about repository separation
- [ ] Share documentation (README, SETUP)
- [ ] Explain new workflow:
  - Infrastructure changes → zebo-terraform
  - App deployments → zebo-infra
- [ ] Update any internal documentation

## ✅ Verification

- [ ] Infrastructure deployment successful
- [ ] Kubernetes deployments still work
- [ ] CI/CD pipelines functional
- [ ] No broken links in documentation
- [ ] Team understands the change

## 📝 Notes

**Important**: Don't delete anything from zebo-infra until zebo-terraform is fully tested and working!

**Timeline**: Complete this checklist within 1-2 days of migration.

---

✅ **Status**: Ready for post-migration setup
