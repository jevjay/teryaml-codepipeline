![teryaml logo](./img/tbits-logo.png)

# teryaml-codepipeline

Terraform based configuration for AWS Codepipeline based CI/CD stack

# Usage

Create a simple Codepipeline job integrated with AWS CodeCommit as a source

```hcl
module "pipelines" {
  source  = "github.com/jevjay/tbits-codepipeline"

  config = "path/to/configuration"
  
  shared_tags = {
    SOME = TAG
  }
```

## Configuration syntax

You can find an overview of module configuration syntax [here](docs/configuration.md)

## Inputs

You can find an overview of module input variables [here](docs/in.md)

## Outputs

You can find an overview of module output values [here](docs/out.md)

## Authors

Originally created by [Jev Jay](https://github.com/jevjay)
Module managed by [Jev Jay](https://github.com/jevjay).

## License

Apache 2.0 licensed. See `LICENSE.md` for full details.
