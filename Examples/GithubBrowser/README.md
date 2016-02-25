# Siesta Example Project

This app allows you to type a Github username and see the user’s name, avator, and repos.

This is a simple app, and intentionally minimizes things outside of Siesta’s purview: no models, minimal functionality, and bare bones UI. (Well, there is the gratuitous use of the Siesta color scheme!)

## Files of note

- `Source/API/GithubAPI.swift` shows how to:
    
    - set up a Siesta service,
    - send an authentication header, and
    - add a custom response transformers that:
        - wrap all JSON responses with SwiftJSON,
        - map endpoints to models, and
        - replace Siesta’s default error messages with Github-provided messages when present.

- `Source/UI/UserViewController.swift` shows how to:
    
    - use Siesta to propagate changes from a Resource to a UI,
    - retarget a view controller at different Resources while it is visible,
    - use `ResourceStatusOverlay` to show a spinner and default error message, and
    - use Siesta’s caching, throttling, and delayed cancellation to manage a rapid series of requests triggered by keystrokes.

- `Source/UI/RepositoryListViewController.swift` shows how to:
    
    - create a view controller which displays a Siesta resource determined by a parent VC and
    - populate a table view with Siesta.

## Rate limit errors?

If you hit the Github API’s rate limit while running the demo, press the “Log In” button. If you’re experimenting with the demo a lot, you can set `GITHUB_USER` and `GITHUB_PASS` environment variables in the “Run” build scheme to make the app automatically log you in on launch.

You can use a [personal access token](https://github.com/settings/tokens) in place of your password. You don’t need to grant any permissions to your token for this app; just the public access will do.
