# Siesta Example Project

This app allows you to search and view GitHub repositories.

It is a simple app, and intentionally minimizes things outside of Siesta’s purview: minimal models, minimal functionality, and bare bones UI. (Well, there is the gratuitous use of the Siesta color scheme!)

## What’s interesting about it?

The app does a live search as you type. The user’s repo list comes from a URL provided in the user profile, so each keystroke triggers a two-request chain.

This cascade of API requests and responses poses several problems:

- **Race condition:** There’s no guarantee that responses arrive in the order requests were sent. If you type `AB`, the app sends requests for `/users/A`, `/users/A/repos`, `/users/AB`, and `/users/AB/repos`. If the app naively populates the UI with whatever response arrived last, the UI could for example end up showing user AB’s profile but user A’s repositories. Instead, we have to make sure that every received response corresponds to the thing the UI currently wants to show. This is a tricky — or at the very least annoying — problem to solve with standard old response callbacks.
- **Redundant requests:** We don’t want the app to re-request a username that the user already typed. In theory, `URLCache` solves this; in practice, you’ll end up fighting hard with the server response headers and the cache’s settings to get good behavior.
- **Unnecessary requests:** As the user types, we don’t want to fill the request pipeline with requests whose results we’ll never use. What want want is to cancel a request after a short delay — but only if the request is no longer needed! A rapid backspace shouldn’t cause a double request.
- **Wiping cache and UI on logout:** We don’t want bits of sensitive information lingering in some view after the user has logged out.

Siesta solves all these problems transparently, with minimal code.

## Files of note

- `Source/API/GitHubAPI.swift` shows how to:

    - set up a Siesta service,
    - send an authentication header, and
    - add a custom response transformers that:
        - wrap all JSON responses with SwiftyJSON,
        - map endpoints to models, and
        - replace Siesta’s default error messages with GitHub-provided messages when present.

- `Source/UI/UserViewController.swift` shows how to:

    - use Siesta to propagate changes from a Resource to a UI,
    - retarget a view controller at different Resources while it is visible,
    - use `ResourceStatusOverlay` to show a spinner and default error message, and
    - use Siesta’s caching, throttling, and delayed cancellation to manage a rapid series of requests triggered by keystrokes.

- `Source/UI/RepositoryListViewController.swift` shows how to:

    - create a view controller which displays a Siesta resource determined by a parent VC and
    - populate a table view with Siesta.

- `Source/UI/RepositoryViewController.swift` shows how to:
    
    - show a single-model resource instead of a collection,
    - make mutating API requests, and
    - update the UI based on the state of a specific request instead of a resource.

## Rate limit errors?

If you hit the GitHub API’s rate limit while running the demo, press the “Log In” button. If you’re experimenting with the demo a lot, you can set `GITHUB_USER` and `GITHUB_PASS` environment variables in the “Run” build scheme to make the app automatically log you in on launch.

You can use a [personal access token](https://github.com/settings/tokens) in place of your password. You don’t need to grant any permissions to your token for this app; just the public access will do.
