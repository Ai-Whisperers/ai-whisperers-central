# Reusable Workflows
#
# Use these in your client repo's `.github/workflows/deploy.yml`:
#
# ```yaml
# name: Deploy
# on:
#   push:
#     branches: [main]
#
# jobs:
#   ci:
#     uses: Ai-Whisperers/ci-cd/.github/workflows/ci-nextjs.yml@main
#     with:
#       site-url: https://yoursite.paragu-ai.com
#     secrets: inherit
#
#   deploy:
#     needs: ci
#     uses: Ai-Whisperers/ci-cd/.github/workflows/deploy-vps.yml@main
#     with:
#       site-name: your-site
#     secrets: inherit
# ```
