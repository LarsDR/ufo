It is useful to sometimes deploy only the task definition without re-building it.  Say for example, you are debugging the task definition and just want to directly edit the `.ufo/output/hi-web.json` definition. You can accomplish this with the `ufo deploy` command.  The `ufo deploy` command will deploy the task definition in `.ufo/output` unmodified.  Example:

  ufo deploy hi-web

The above command does the following:

1. register the `.ufo/output/hi-web.json` task definition to ECS untouched.
2. deploys it to ECS by updating the service

The `ufo deploy` command does less than the `ufo ship` command.  Typically, people use `ufo ship` over the `ufo deploy` command do everything in one step:

1. build the Docker image
2. register the ECS task definition
3. update the ECS service
