module AlmaSpecHelpers
  # @param [Hash, nil] additional_params
  def item_identifiers(additional_params = nil)
    identifiers = { mms_id: '1234', holding_id: '2345', item_pid: '3456' }
    return identifiers unless additional_params

    identifiers.merge additional_params
  end
end
