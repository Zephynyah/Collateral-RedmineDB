Import-module PSRedmine -Force

InModuleScope PSRedmine {
    Describe 'Redmine API' {
        Context 'New-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'POST' -and $Body -and $Uri -like "/projects.json" }
            It 'project' { New-RedmineDB -identifier test99 -name testproject }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'POST' -and $Body -and $Uri -like "/projects/*/versions.json" }
            It 'version' { New-RedmineDB -identifier test99 -name testversion -project_id 475 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'POST' -and $Body -and $Uri -like "/issues.json" }
            It 'issue' { New-RedmineResource issue -project_id test99 -subject testissue }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 3 -Exactly
        }
        Context 'Search-RedmineDB' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects.json?offset=*&limit=*" }
            It 'project' { Search-RedmineDB project -keyword testproject }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects/*/memberships.json?offset=*&limit=*" }
            It 'membership' { Search-RedmineDB membership -project_id test99 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects/*/versions.json" }
            It 'version' { Search-RedmineDB version -keyword testversion -project_id test99 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/issues.json?offset=*&limit=*" }
            It 'issue' { Search-RedmineDB issue -keyword testissue }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/users.json?offset=*&limit=*" }
            It 'user' { Search-RedmineDB user -keyword testuser }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 5 -Exactly
        }
        Context 'Get-RedmineDB' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects/*.json" }
            It 'project' { Get-RedmineDB project -id test99 }
            It 'project' { Get-RedmineDB project 12 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/memberships/*.json" }
            It 'membership' { Get-RedmineDB membership 123 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/versions/*.json" }
            It 'version' { Get-RedmineDB version 123 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/issues/*.json?include=children,attachments,relations,journals,watchers" }
            It 'issue' { Get-RedmineDB issue 1234 }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 5 -Exactly
        }
        Context 'Edit-RedmineDB' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'PUT' -and $Body -and $Uri -like "/*/*.json" }
            It 'project' { Edit-RedmineDB project -id 12 -description 'change description' }
            It 'version' { Edit-RedmineDB version -id 123 -description 'add desc' -due_date 2018-09-29 }
            It 'issue' { Edit-RedmineDB issue -id 1234 -version_id 123 }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 3 -Exactly
        }
        Context 'Remove-RedmineDB' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'DELETE' -and $Uri -like "/*/*.json" }
            It 'project' { Remove-RedmineDB project -id 12 }
            It 'version' { Remove-RedmineDB version -id 123 }
            It 'issue' { Remove-RedmineDB issue -id 1234 }
            It 'user' { Remove-RedmineDB user -id 20 }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 4 -Exactly
        }
    }
}
