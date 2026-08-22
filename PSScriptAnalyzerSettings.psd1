@{
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        # UI helpers and text-normalization functions do not mutate system state.
        'PSUseShouldProcessForStateChangingFunctions'

        # These internal names are established and clearer in their plural form.
        'PSUseSingularNouns'

        # Start-Job receives values through -ArgumentList, not closure capture.
        'PSUseUsingScopeModifierInNewRunspaces'
    )
}
