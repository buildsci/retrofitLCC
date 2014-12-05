#watcher
class RunManagerWatcherImpl < OpenStudio::Runmanager::RunManagerWatcher
  def initialize(runmanager)
  super
    @m_finishedCounts=[]
  end

  def finishedCounts
    return @m_finishedCounts
  end

  def jobFinishedDetails(t_jobId, t_jobType, t_lastRun, t_errors, t_outputFiles, t_inputParams, t_isMergedJob, t_mergedIntoJobId)
    #puts "JobFinished: #{t_jobId} #{t_jobType.valueName} Run Time:#{t_lastRun} #{t_errors.succeeded} #{t_outputFiles.files.size} #{t_outputFiles.files.at(0).fullPath} #{t_inputParams.params.size} #{t_isMergedJob} #{t_mergedIntoJobId}\n"
	puts "\nJob Type:#{t_jobType.valueName}\nJob Executed With No Errors?:#{t_errors.succeeded}\nFile Path:#{t_outputFiles.files.at(0).fullPath}\n"

    if not @m_finishedCounts[t_jobType.value]
      @m_finishedCounts[t_jobType.value] = 1
    else
      @m_finishedCounts[t_jobType.value] += 1
    end
  end

  def treeFinished(t_job)
    puts "\nJob Tree Finished"
    if not @m_finishedCounts[999]
      @m_finishedCounts[999] = 1
    else
      @m_finishedCounts[999] += 1
    end
  end
  
end