require 'helpers/class_extensions'
require 'rspreadsheet/xml_tied_array'

module Rspreadsheet

using ClassExtensions if RUBY_VERSION > '2.1'


# Abstract class similar to XMLTiedArray but with support to "repeatable" items. This is notion specific
# to OpenDocument files - whenewer a row repeats more times (or a cell), one can either make many identical
# copies of the same xml or only make one xml representing one item and add attribute xml_repeated.
#
# This class is made to be included, not subclassed - the reason is in delete method which calls super.
# This class is also made to handle automatic creation of outbound items.
# @private

module XMLTiedArray_WithRepeatableItems
  include XMLTiedArray

  def my_subnode_range(aindex)
    _, range = find_subnode_with_range(aindex)
    return range
  end
  
  # vrátí xmlnode na souřadnici aindex
  def my_subnode(aindex)
    result1, _ = find_subnode_with_range(aindex)
    return result1
  end

  def find_subnode_with_range(aindex)
    options = subnode_options
    rightindex = 0
    xmlsub = self.xmlsubnodes
    xmlsub.each do |node|
      repeated = (node.attributes[options[:repeated_attribute]] || 1).to_i
      leftindex = rightindex + 1 
      rightindex = rightindex+repeated
      if rightindex>= aindex
        return node, leftindex..rightindex
      end
    end
    return nil, rightindex+1..Float::INFINITY
  end
  
  # @!group inserting new subnodes
    
  def insert_new_empty_subnode_before_respect_repeatable(aindex)
    new_subnode = prepare_repeated_subnode(1, subnode_options)
    insert_subnode_before_respect_repeatable(new_subnode, aindex)
  end
  alias :insert_new_empty_subnode_before :insert_new_empty_subnode_before_respect_repeatable
  
  def insert_subnode_before_respect_repeatable(subnode,aindex)
    axmlnode = xmlnode
    options = subnode_options
    node,index_range = find_subnode_with_range(aindex)
    
    if !node.nil? # found the node, now do the insert
      [index_range.begin..aindex-1,aindex..index_range.end].reject {|range| range.size<1}.each do |range| # split  original node by cloning
        clone_before_and_set_repeated_attribute(node,range.size,options)
      end
      node.prev.prev =  subnode                   # insert subnode
      node.remove!                                # remove the original node
    else # insert outbound xmlnode
      number_of_preceeding_items = aindex-1-(index+1)+1 
      axmlnode << prepare_repeated_subnode(number_of_preceeding_items, options) unless number_of_preceeding_items<1 # insert preceeding cells
      axmlnode << subnode                         # insert subnode
    end #TODO: Out of bounds indexes handling
    return my_subnode(aindex)
  end
  alias :insert_subnode_before :insert_subnode_before_respect_repeatable
  
  def prepare_repeated_subnode(times_repeated,options)
    result = prepare_empty_subnode
    Tools.set_ns_attribute(result,'table',options[:repeated_attribute],times_repeated, 1)
    result
  end
  
  def clone_before_and_set_repeated_attribute(node,times_repeated,options)
    newnode = node.copy(true)
    Tools.set_ns_attribute(newnode,'table',options[:repeated_attribute],times_repeated,1)
    node.prev = newnode
  end
  
  # takes item on source_index, clones it and inserts it before target_index
  def clone_item_before(source_index, target_index)
    newnode = my_subnode(source_index).copy(true)
    Tools.delete_ns_attribute(newnode,'table',subnode_options[:repeated_attribute])
    insert_subnode_before_respect_repeatable(newnode,target_index)
  end

  # detaches subnode with aindex  
  def detach_my_subnode_respect_repeated(aindex)
    axmlnode = xmlnode
    options = subnode_options
    node,index_range = find_subnode_with_range(aindex)
    if index_range.size > 1 # pokud potřebuje vůbec detachovat
      if !node.nil? # detach subnode
        [index_range.begin..aindex-1,aindex..aindex,aindex+1..index_range.end].reject {|range| range.size<1}.each do |range| # create new structure by cloning
          clone_before_and_set_repeated_attribute(node,range.size,options)
        end
        node.remove! # remove the original node
      else # add outbound xmlnode
        [index_range.begin..aindex-1,aindex..aindex].reject {|range| range.size<1}.each do |range|
          axmlnode << prepare_repeated_subnode(range.size, options)
        end
      end
    end
    return my_subnode(aindex)
  end
  
  def delete_my_subnode_respect_repeated(aindex)
    detach_my_subnode_respect_repeated(aindex) #TODO: tohle neni uplne spravne, protoze to zanecha skupinu rozdelenou na dve casti
    subitem(aindex).xmlnode.remove!
  end
  
  def how_many_times_node_is_repeated(node)   # adding respect to repeated nodes
    (node.attributes[subnode_options[:repeated_attribute]] || 1).to_i
  end
  
  # clean up item from xml (handle possible detachments) and itemcache. leave the object invalidation on the object
  # this should not be called from nowhere but XMLTiedItem.delete
  def delete_subitem(aindex)
#     options = subnode_options
    delete_my_subnode_respect_repeated(aindex)  # vymaž node z xml
    @itemcache.delete(aindex)
    @itemcache.keys.sort.select{|i| i>=aindex+1 }.each do |i| 
      @itemcache[i-1]=@itemcache.delete(i)
      @itemcache[i-1]._shift_by(-1)
    end
  end
  
  def delete
    @itemcache.each do |key,item| 
      item.delete   # delete item - this destroys its subitems, xmlnode and invalidates it
      @itemcache.delete(key)  # delete the entry from the hash, normally this would mean this ceases to exist, if user does not have reference stored somewhere. Of he does, the object is invalidated anyways
    end
    super # this for example for Row objects calls XMLTiedItem.delete because Row is subclass of XMLTiedItem
  end

  def find_nonempty_subnode_indexes(axmlnode, options)
    index = 0
    result = []
    axmlnode.elements.select{|node| node.name == options[:node_name]}.each do |node|
      repeated = (node.attributes[options[:repeated_attribute]] || 1).to_i
      index = index + repeated
      if !(node.content.nil? or node.content.empty? or node.content =='') and (repeated==1)
        result << index
      end
    end
    return result
  end

  # truncate the item completely, deleting all its subitems
  def truncate
    subitems.reverse.each{ |subitem| subitem.delete }  # reverse je tu jen kvuli performanci, aby to mazal zezadu
  end  
end

end
