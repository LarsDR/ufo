require 'thor'
require 'ufo/command'

module Ufo
  class CLI < Command
    class_option :verbose, type: :boolean
    class_option :mute, type: :boolean
    class_option :noop, type: :boolean
    class_option :cluster, desc: "Cluster.  Overrides ufo/settings.yml."

    desc "docker SUBCOMMAND", "docker related tasks"
    long_desc Help.text(:docker)
    subcommand "docker", Docker

    desc "tasks SUBCOMMAND", "task definition related tasks"
    long_desc Help.text(:tasks)
    subcommand "tasks", Tasks

    long_desc Help.text(:init)
    Init.cli_options.each do |args|
      option *args
    end
    register(Init, "init", "new", "setup initial ufo files")

    # common options to deploy. ship, and ships command
    ship_options = Proc.new do
      option :task, desc: "ECS task name, to override the task name convention."
      option :target_group, desc: "ELB Target Group ARN."
      option :target_group_prompt, type: :boolean, desc: "Enable Target Group ARN prompt", default: true
      option :wait, type: :boolean, desc: "Wait for deployment to complete", default: false
      option :pretty, type: :boolean, default: true, desc: "Pretty format the json for the task definitions"
      option :stop_old_tasks, type: :boolean, default: false, desc: "Stop old tasks after waiting for deploying to complete"
      option :ecr_keep, type: :numeric, desc: "ECR specific cleanup of old images.  Specifies how many images to keep.  Only runs if the images are ECR images. Defaults keeps all images."
    end

    desc "deploy SERVICE", "deploys task definition to ECS service without re-building the definition"
    long_desc Help.text(:deploy)
    ship_options.call
    def deploy(service)
      task_definition = options[:task] || service # convention
      Tasks::Register.register(task_definition, options)
      ship = Ship.new(service, task_definition, options)
      ship.deploy
    end

    desc "ship SERVICE", "builds and ships container image to the ECS service"
    long_desc Help.text(:ship)
    ship_options.call
    def ship(service)
      builder = build_docker

      task_definition = options[:task] || service # convention
      Tasks::Builder.ship(task_definition, options)
      ship = Ship.new(service, task_definition, options)
      ship.deploy

      cleanup(builder.image_name)
    end

    desc "ships [LIST_OF_SERVICES]", "builds and ships same container image to multiple ECS services"
    long_desc Help.text(:ships)
    ship_options.call
    def ships(*services)
      builder = build_docker

      services.each_with_index do |service|
        service_name, task_definition_name = service.split(':')
        task_definition = task_definition_name || service_name # convention
        Tasks::Builder.ship(task_definition, options)
        ship = Ship.new(service, task_definition, options)
        ship.deploy
      end

      cleanup(builder.image_name)
    end

    desc "task TASK_DEFINITION", "runs a one time task"
    long_desc Help.text(:task)
    option :docker, type: :boolean, desc: "Enable docker build and push", default: true
    option :command, type: :array, desc: "Override the command used for the container"
    def task(task_definition)
      Docker::Builder.build(options)
      Tasks::Builder.ship(task_definition, options)
      Task.new(task_definition, options).run
    end

    desc "destroy SERVICE", "destroys the ECS service"
    long_desc Help.text(:destroy)
    option :sure, type: :boolean, desc: "By pass are you sure prompt."
    def destroy(service)
      task_definition = options[:task] || service # convention
      Destroy.new(service, options).bye
    end

    desc "scale SERVICE COUNT", "scale the ECS service"
    long_desc Help.text(:scale)
    def scale(service, count)
      Scale.new(service, count, options).update
    end

    desc "completion *PARAMS", "prints words for auto-completion"
    long_desc Help.text("completion")
    def completion(*params)
      Completer.new(CLI, *params).run
    end

    desc "completion_script", "generates script that can be eval to setup auto-completion", hide: true
    long_desc Help.text("completion_script")
    def completion_script
      Completer::Script.generate
    end

    desc "upgrade3", "upgrade from version 2 to 3"
    long_desc Help.text("upgrade3")
    def upgrade3
      Upgrade3.new(options).run
    end

    desc "version", "Prints version number of installed ufo"
    def version
      puts VERSION
    end

    no_tasks do
      def build_docker
        builder = Docker::Builder.new(options)
        builder.build
        builder.push
        builder
      end

      def cleanup(image_name)
        Docker::Cleaner.new(image_name, options).cleanup
        Ecr::Cleaner.new(image_name, options).cleanup
      end
    end
  end
end
