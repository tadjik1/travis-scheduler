module Travis
  module Scheduler
    module Serialize
      class Worker < Struct.new(:job, :config)
        require 'travis/scheduler/serialize/worker/build'
        require 'travis/scheduler/serialize/worker/commit'
        require 'travis/scheduler/serialize/worker/config'
        require 'travis/scheduler/serialize/worker/job'
        require 'travis/scheduler/serialize/worker/request'
        require 'travis/scheduler/serialize/worker/repo'
        require 'travis/scheduler/serialize/worker/ssh_key'

        def data
          data = {
            type: :test,
            vm_config: job.vm_config,
            vm_type: repo.vm_type,
            queue: job.queue,
            config: job.decrypted_config,
            env_vars: job.env_vars,
            job: job_data,
            host: Travis::Scheduler.config.host,
            source: build_data,
            repository: repository_data,
            ssh_key: ssh_key.data,
            timeouts: repo.timeouts,
            cache_settings: cache_settings,
            enterprise: !!config[:enterprise],
            prefer_https: !!config[:prefer_https]
          }
          data[:trace]  = true if job.trace?
          data[:warmer] = true if job.warmer?
          data[:oauth_token] = github_oauth_token if config[:prefer_https]
          data
        end

        private

          def build_data
            {
              id: build.id,
              number: build.number,
              event_type: build.event_type
            }
          end

          def job_data
            data = {
              id: job.id,
              number: job.number,
              commit: commit.commit,
              commit_range: commit.range,
              commit_message: commit.message,
              branch: commit.branch,
              ref: commit.pull_request? ? commit.ref : nil,
              tag: commit.tag,
              pull_request: build.pull_request? ? build.pull_request_number : false,
              state: job.state.to_s,
              secure_env_enabled: job.secure_env?,
              secure_env_removed: job.secure_env_removed?,
              debug_options: job.debug_options || {},
              queued_at: format_date(job.queued_at),
              allow_failure: job.allow_failure,
              stage_name: job.stage&.name,
            }
            if build.pull_request?
              data = data.merge(
                pull_request_head_branch: request.pull_request_head_ref,
                pull_request_head_sha: request.pull_request_head_sha,
                pull_request_head_slug: request.pull_request_head_slug,
              )
            end
            data
          end

          def repository_data
            compact(
              id: repo.id,
              github_id: repo.github_id,
              installation_id: repo.installation_id,
              private: repo.private?,
              slug: repo.slug,
              source_url: source_url,
              source_host: source_host,
              api_url: repo.api_url,
              # TODO how come the worker needs all these?
              last_build_id: repo.last_build_id,
              last_build_number: repo.last_build_number,
              last_build_started_at: format_date(repo.last_build_started_at),
              last_build_finished_at: format_date(repo.last_build_finished_at),
              last_build_duration: repo.last_build_duration,
              last_build_state: repo.last_build_state.to_s,
              default_branch: repo.default_branch,
              description: repo.description
            )
          end

          def source_url
            # TODO move these things to Build
            return repo.source_git_url if repo.private? && ssh_key.custom?
            repo.source_url
          end

          def job
            @job ||= Job.new(super, config)
          end

          def repo
            @repo ||= Repo.new(job.repository, config)
          end

          def request
            @request ||= Request.new(build.request)
          end

          def commit
            @commit ||= Commit.new(job.commit)
          end

          def build
            @build ||= Build.new(job.source)
          end

          def ssh_key
            @ssh_key ||= SshKey.new(repo, job, config)
          end

          def source_host
            config[:github][:source_host] || 'github.com'
          end

          def cache_settings
            cache_config[job.queue].to_h if cache_config[job.queue]
          end

          def cache_config
            config[:cache_settings] || {}
          end

          def format_date(date)
            date && date.strftime('%Y-%m-%dT%H:%M:%SZ')
          end

          def github_oauth_token
            scope = job.repository.users
            scope = scope.where("github_oauth_token IS NOT NULL").order("updated_at DESC")
            admin = scope.first
            admin && admin.github_oauth_token
          end

          def compact(hash)
            hash.reject { |_, value| value.nil? }
          end
      end
    end
  end
end
