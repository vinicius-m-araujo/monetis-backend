using Monetis.Domain.Enums;

namespace Monetis.Application.DTOs;

public record CategoryResponse(Guid Id, string Name, string Icon);
public record CreateCategoryRequest(string Name, string Icon);
public record UpdateCategoryRequest(string Name, string Icon);
