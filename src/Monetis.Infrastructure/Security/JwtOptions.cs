using System.ComponentModel.DataAnnotations;

namespace Monetis.Infrastructure.Security;

public class JwtOptions
{
    public const string SectionName = "Jwt";

    [Required(AllowEmptyStrings = false)]
    [MinLength(32, ErrorMessage = "The JWT key must be at least 32 characters long")]
    public string Key { get; init; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    public string Issuer { get; init; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    public string Audience { get; init; } = string.Empty;

    [Range(220,250, ErrorMessage = "The JWT duration must be between 220 and 250 minutes")]
    public int DurationInMinutes { get; init; } = 240;
}
