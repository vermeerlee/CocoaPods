require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Command::Repo" do
  describe "In general" do
  extend SpecHelper::Command
  extend SpecHelper::TemporaryDirectory
  extend SpecHelper::TemporaryRepos

    it "runs with correct parameters" do
      lambda { run_command('repo', 'add', 'NAME', 'URL') }.should.not.raise
      lambda { run_command('repo', 'update') }.should.not.raise
      lambda { run_command('repo', 'lint',  temporary_directory.to_s) }.should.not.raise
    end

    it "complains for wrong parameters" do
      lambda { run_command('repo', 'add') }.should.raise Pod::Informative
      lambda { run_command('repo', 'add', 'NAME') }.should.raise Pod::Informative
    end

    it "adds a spec-repo" do
      add_repo('private', fixture('spec-repos/master'))
      git_config('private', 'remote.origin.url').should == fixture('spec-repos/master').to_s
    end

    it "adds a spec-repo with on a specified branch" do
      repo1 = add_repo('repo1', fixture('spec-repos/master'))
      Dir.chdir(repo1.dir) do
        `git checkout -b my-branch >/dev/null 2>&1`
        `git checkout master >/dev/null 2>&1`
      end
      repo2 = command( 'repo' ,'add', 'repo2', repo1.dir, 'my-branch')
      repo2.run
      Dir.chdir(repo2.dir) { `git symbolic-ref HEAD` }.should.include? 'my-branch'
    end

    it "updates a spec-repo" do
      repo1 = add_repo('repo1', fixture('spec-repos/master'))
      repo2 = add_repo('repo2', repo1.dir)
      make_change(repo1, 'repo1')
      run_command('repo', 'update', 'repo2')
      (repo2.dir + 'README').read.should.include 'Added!'
    end

    it "updates all the spec-repos" do
      repo1 = add_repo('repo1', fixture('spec-repos/master'))
      repo2 = add_repo('repo2', repo1.dir)
      repo3 = add_repo('repo3', repo1.dir)
      make_change(repo1, 'repo1')
      run_command('repo', 'update')
      (repo2.dir + 'README').read.should.include 'Added!'
      (repo3.dir + 'README').read.should.include 'Added!'
    end

    before do
      config.repos_dir = fixture('spec-repos')
    end

    it "lints a repo" do
      cmd = command('repo', 'lint', 'master')
      lambda { cmd.run }.should.raise Pod::Informative
      cmd.output.should.include "Missing license type"
    end
  end

  describe "Concerning a repo support" do
  extend SpecHelper::Command
  extend SpecHelper::TemporaryDirectory
  extend SpecHelper::TemporaryRepos

    before do
      add_repo('repo1', fixture('spec-repos/master'))
      FileUtils.rm_rf(versions_file)
      versions_file.should.not.exist?
    end

    require 'yaml'

    def versions_file
      tmp_repos_path + "repo1/CocoaPods-version.yml"
    end

    it "it doesn't requires CocoaPods-version.yml" do
      lambda { run_command('repo', 'update') }.should.not.raise
    end

    it "runs with a compatible repo" do
      yaml = YAML.dump({'min' => "0.0.1"})
      File.open(versions_file, 'w') {|f| f.write(yaml) }
      lambda { run_command('repo', 'update') }.should.not.raise
    end

    it "raises if a repo is not compatible" do
      yaml = YAML.dump({'min' => "999.0.0"})
      File.open(versions_file, 'w') {|f| f.write(yaml) }
      lambda { run_command('repo', 'update') }.should.raise Pod::Informative
    end

    it "does not inform about a higher known CocoaPods version since this is intrusive and obnoxious" do
      yaml = YAML.dump({'last' => "999.0.0"})
      File.open(versions_file, 'w') {|f| f.write(yaml) }
      run_command('repo', 'update').should.not.include "Cocoapods 999.0.0 is available"
    end

    it "has a class method that returns if a repo is supported" do
      yaml = YAML.dump({'min' => "999.0.0"})
      File.open(versions_file, 'w') {|f| f.write(yaml) }
      Pod::Command::Repo.compatible?('repo1').should == false

      yaml = YAML.dump({'min' => "0.0.1"})
      File.open(versions_file, 'w') {|f| f.write(yaml) }
      Pod::Command::Repo.compatible?('repo1').should == true
    end
  end
end
