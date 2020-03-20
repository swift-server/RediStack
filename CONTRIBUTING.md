## Legal

By submitting a pull request, you represent that you have the right to license your contribution to the community, and agree by submitting the patch
that your contributions are licensed under the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0.html) (see [`LICENSE`](../LICENSE)).

## Contributor Conduct

All contributors are expected to adhere to this project's [Code of Conduct](CODE_OF_CONDUCT.md).

## Development

### File Copyright Headers

When adding a new file to the project, add the following heading to the top of the file:

```
//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
```

When editing a file, ensure that the copyright header states the year `2019-<current year>`.

### Git Workflow

`master` is always the development branch.

For **minor** or **patch** SemVer changes, create a branch off of the tagged commit.

### Environment Setup

It is highly recommended to use [Docker](https://docker.com) to install Redis locally.

```bash
docker run -d -p 6379:6379 --name redis redis:5
```

Otherwise, install Redis directly on your machine from [Redis.io](https://redis.io/download).
  
### Submitting a Merge Request

> The easiest way to create a great merge requests is to use one of the [Merge Request Templates](./.gitlab/merge_request_templates).
  
A great MR that is likely to be merged quickly is:
  
1. Concise, with as few changes as needed to achieve the end result.
1. Tested, ensuring that regressions aren't introduced now or in the future.
1. Documented, adding API documentation as needed to cover new functions and properties.
1. Accompanied by a [great commit message](https://chris.beams.io/posts/git-commit/)
