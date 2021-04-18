# include guard
ifneq ($(myci_is_included),true)
    myci_is_included := true

    # include makefile if it is not included already, does not fail if file does not exist
    define myci-try-include
        $(eval myci_private_include_file := $(abspath $1))
        $(if $(filter $(myci_private_include_file),$(MAKEFILE_LIST)), \
                , \
                -include $(myci_private_include_file) \
            )
    endef

endif
