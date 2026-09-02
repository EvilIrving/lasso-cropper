# 套索导出 website

Static site for `https://lasso.onecat.dev/`, hosted on Cloudflare Pages (`lasso-export`).

## URLs

- Home: `https://lasso.onecat.dev/`
- Privacy: `https://lasso.onecat.dev/privacy`
- Support: `https://lasso.onecat.dev/support`

## Deploy

From this directory (needs local proxy if Cloudflare API is blocked):

```sh
export HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890
wrangler pages deploy . --project-name lasso-export --branch main
```

No build step.
