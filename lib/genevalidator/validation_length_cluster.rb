require 'genevalidator/validation_output'
require 'genevalidator/validation_test'

##
# Class that stores the validation output information
class LengthClusterValidationOutput < ValidationReport

  attr_reader :prediction_len
  attr_reader :limits

  def initialize (prediction_len, limits)
    @limits = limits
    @prediction_len = prediction_len
  end

  def print
    "#{@prediction_len} #{@limits.to_s}"
  end

  def validation

    if @limits != nil
      if @prediction_len >= @limits[0] and @prediction_len <= @limits[1]
        :yes
      else
        :no
      end
    end    
  end
end

##
# This class contains the methods necessary for 
# length validation by hit length clusterization
class LengthClusterValidation < ValidationTest

  attr_reader :filename
  attr_reader :plot
  attr_reader :clusters
  attr_reader :max_density_cluster

  ##
  # Initilizes the object
  # Params:
  # +type+: type of the predicted sequence (:nucleotide or :protein)
  # +prediction+: a +Sequence+ object representing the blast query
  # +hits+: a vector of +Sequence+ objects (usually representig the blast hits)
  # +plot_filename+: name of the input file, used when generatig the plot files
  # +plot+: boolean variable, indicated whether plots should be generated or not
  def initialize(type, prediction, hits, filename, plot = true)
    super
    @filename = filename
    @plot = plot
    @short_header = "Valid_Length(Cluster)"
    @header = "Valid Length(Cluster)"
    @description = "Check whether the prediction length fits the most of the BLAST hit lengths, by 1D hierarchical clusterization."
  end

  ## 
  # Validates the length of the predicted gene by comparing the length of the prediction to the most dense cluster
  # The most dense cluster is obtained by hierarchical clusterization
  # Plots are generated if required (see +plot+ variable)
  # Output:
  # +LengthClusterValidationOutput+ object
  def run
    begin
      raise Exception unless prediction.is_a? Sequence and hits[0].is_a? Sequence

      ret = clusterization_by_length  #returns [clusters, max_density_cluster_idx]

      @clusters = ret[0]
      @max_density_cluster = ret[1]
      limits = @clusters[@max_density_cluster].get_limits
      prediction_len = @prediction.xml_length

      if plot
        plot_histo_clusters("#{@filename}_len_clusters.jpg")
        plot_files.push("#{@filename}_len_clusters.jpg")
        plot_length("#{@filename}_len.jpg")
        plot_files.push("#{@filename}_len.jpg")
      end

      @validation_report = LengthClusterValidationOutput.new(prediction_len, limits)
      @validation_report.plot_files = plot_files

    # Exception is raised when blast founds no hits
    rescue Exception => error
      ValidationReport.new("Not enough evidence")
    end
       
  end

  ##
  # Clusterization by length from a list of sequences
  # Params:
  # +debug+ (optional):: true to display debug information, false by default (optional argument)
  # +lst+:: array of +Sequence+ objects
  # +predicted_seq+:: +Sequence+ objetc
  # Output
  # output 1:: array of Cluster objects
  # output 2:: the index of the most dense cluster
  def clusterization_by_length(debug = false, lst = @hits, predicted_seq = @prediction)
    begin
      raise TypeError unless lst[0].is_a? Sequence and predicted_seq.is_a? Sequence

      contents = lst.map{ |x| x.xml_length.to_i }.sort{|a,b| a<=>b}

      hc = HierarchicalClusterization.new(contents)
      clusters = hc.hierarchical_clusterization

      max_density = 0;
      max_density_cluster_idx = 0;
      clusters.each_with_index do |item, i|
        if item.density > max_density
          max_density = item.density
          max_density_cluster_idx = i;
        end
      end

      return [clusters, max_density_cluster_idx]

    rescue TypeError => error
      $stderr.print "Type error at #{error.backtrace[0].scan(/\/([^\/]+:\d+):.*/)[0][0]}. Possible cause: one of the arguments of 'clusterization_by_length' method has not the proper type.\n"
      exit
    end
  end

  ##
  # Plots lines corresponding to each length
  # Highlights the start and end hit offsets
  # +output+: filename where to save the graph
  # +lst+: array of Sequence objects
  # +predicted_seq+: Sequence object
  def plot_length(output = "#{filename}_len.jpg", lst = @hits, predicted_seq = @prediction)
    max_len = lst.map{|x| x.xml_length.to_i}.max
    lst = lst.sort{|a,b| a.xml_length<=>b.xml_length}

    max_plots = 120
    skip= lst.length/max_plots

    R.eval "jpeg('#{output}')"
    R.eval "plot(1:#{[lst.length-1,max_plots].min}, xlim=c(0,#{max_len}), xlab='Hit Length (black) vs part of the hit that matches the query (red)',ylab='Hit Number', col='white', main='Hits vs query')"
    height = -1;
    lst.each_with_index do |seq,i|
      if skip == 0 or i%skip == 0
        height += 1
        R.eval "lines(c(1,#{seq.xml_length}), c(#{height}, #{height}), lwd=10)"
        seq.hsp_list.each do |hsp|
          R.eval "lines(c(#{hsp.hit_from},#{hsp.hit_to}), c(#{height}, #{height}), lwd=6, col='red')"
        end
      end
    end
    R.eval "dev.off()"
  end

  ##
  # Plots a histogram of the length distribution given a list of Cluster objects
  # Params:
  # +output+: filename where to save the graph
  # +clusters+: array of Cluster objects
  # +predicted_length+: length of the rpedicted sequence
  # +most_dense_cluster_idx+index from the clusters array of the most_dense_cluster_idx
  def plot_histo_clusters(output = "#{filename}_len_clusters.jpg", clusters = @clusters, predicted_length = @prediction.xml_length, 
                          most_dense_cluster_idx = @max_dense_cluster)
    begin
      raise TypeError unless clusters[0].is_a? Cluster and predicted_length.is_a? Fixnum

      lengths = clusters.map{ |c| c.lengths.sort{|a,b| a[0]<=>b[0]}.map{ |x| a = Array.new(x[1],x[0])}.flatten}.flatten
      lengths.push(predicted_length)

      max_freq = clusters.map{ |x| x.lengths.map{|y| y[1]}.max}.max
      #make the plot in a new process
        R.eval "colors = c('orange', 'blue', 'yellow', 'green', 'gray')"

        unless output == nil
          #puts "---- #{output}"
          #R.eval "dev.copy(png,'#{output}.png')"
          R.eval "jpeg('#{output}')"
        end

        clusters.each_with_index do |cluster, i|
          cluster_lengths = cluster.lengths.sort{|a,b| a[0]<=>b[0]}.map{ |x| a = Array.new(x[1],x[0])}.flatten

          if i == @max_density_cluster
            color = "'red'"
          else
            color = "colors[#{i%5+1}]"
          end

          R.eval "hist(c#{cluster_lengths.to_s.gsub('[','(').gsub(']',')')},
                     breaks = seq(#{lengths.min-10}, #{lengths.max+10}, 0.1),
                     xlim=c(#{lengths.min-10},#{lengths.max+10}),
                     ylim=c(0,#{max_freq}),
                     col=#{color},
                     border=#{color},
                     main='Histogram for length distribution', xlab='length\nblack = predicted sequence, red = most dense cluster')"
          R.eval "par(new=T)"
        end

        R.eval "abline(v=#{predicted_length})"

        unless output == nil
          R.eval "dev.off()"
        end
    end
  end

  ##
  # Calculates the silhouette score of the sequence
  # Params:
  # +seq+: Sequence object
  # +idx+: index of the cluster with the maximul internisty
  # +clusters+:array of +Cluster+ objects
  # Output
  # the silhouette of the sequence
  def sequence_silhouette (seq = @prediction, idx = @max_density_cluster, clusters = @clusters)
    seq_len = seq.xml_length

    #the average dissimilarity of the sequence with other elements in idx cluster
    a = 0
    clusters[idx].lengths.each do |len, frecv|
      a = a + (len - seq_len).abs
    end
    a = a.to_f / clusters[idx].lengths.length

    b_vector = Array.new

    clusters.each_with_index do |cluster, i|
      #the average dissimilarity of the sequence with the members of cluster i
      if i != idx
        b = 0
        cluster.lengths.each do |len, frecv|
          b = b + (len - seq_len).abs
        end
        b = b.to_f / cluster.lengths.length
        unless b == 0
          b_vector.push(b)
        end
      end
    end
    b = b_vector.min
    if b == nil
      b=0
    end
    silhouette = (b - a).to_f / [a,b].max
    return silhouette
  end

end