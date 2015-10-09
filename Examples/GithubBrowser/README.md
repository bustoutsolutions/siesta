# Siesta Example Project

This app allows you to type a Github username and see the user’s name, avator, and repos.

This is a simple app, and intentionally minimizes things outside of Siesta’s purview: no models, bare bones UI, minimal functionality.

## Files of note

- `Source/API/GithubAPI.swift` shows how to:
    - set up a Siesta service,
    - send an authentication header, and
    - add a custom response transformer (in this case to extract Github-provided error messages).
- `Source/API/Siesta+SwiftyJSON.swift` shows how to:
    - integrate SwiftyJSON and
    - how to write your own typed convenience accessor.
- `Source/UI/UserViewController.swift` shows how to:
    - use Siesta to propagate changes from a Resource to a UI,
    - retarget a view controller at different Resources while it is visible,
    - use `ResourceStatusOverlay` to show a spinner and default error message, and
    - use Siesta’s caching, throttling, and delayed cancellation to manage a rapid series of requests.
- `Source/UI/RepositoryListViewController.swift` shows how to:
    - create a view controller which displays a Siesta resource determined by a parent VC and
    - populate a table view with Siesta.

## Rate limit errors?

If you hit the Github API’s rate limit while running the demo, configure the app to authenticate itself with Github by adding `GITHUB_USER` and `GITHUB_PASS` environment variables to the “Run” build scheme.

You can also use a [personal access token](https://github.com/settings/tokens) in place of your password. You don’t need to grant any permissions to your token for this app; just the public access will do.
